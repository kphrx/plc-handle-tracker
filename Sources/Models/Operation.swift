import Fluent
import FluentPostgresDriver
import Vapor

final class Operation: Model, Content {
  static let schema = "operations"

  final class IDValue: Fields, Hashable {
    @Field(key: "cid")
    var cid: String

    @Parent(key: "did")
    var did: Did

    init() {}

    init(cid: String, did: Did.IDValue) {
      self.cid = cid
      self.$did.id = did
    }

    static func == (lhs: IDValue, rhs: IDValue) -> Bool {
      lhs.cid == rhs.cid && lhs.$did.id == rhs.$did.id
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(self.cid)
      hasher.combine(self.$did.id)
    }
  }
  @CompositeID var id: IDValue?

  var did: Did {
    self.id!.did
  }

  @Field(key: "nullified")
  var nullified: Bool

  @Timestamp(key: "created_at", on: .none)
  var createdAt: Date!

  @CompositeOptionalParent(prefix: "prev")
  var prev: Operation?

  @CompositeChildren(for: \.$prev)
  var nexts: [Operation]

  @OptionalParent(key: "handle")
  var handle: Handle?

  @OptionalParent(key: "pds")
  var pds: PersonalDataServer?

  init() {}

  init(
    cid: String, did: String, nullified: Bool, createdAt: Date,
    prev: Operation? = nil, handle: Handle? = nil, pds: PersonalDataServer? = nil
  ) throws {
    self.id = .init(cid: cid, did: did)
    self.nullified = nullified
    self.createdAt = createdAt
    if let prevId = try prev?.requireID() {
      self.$prev.id = .init(cid: prevId.cid, did: prevId.$did.id)
    }
    self.$handle.id = try handle?.requireID()
    self.$pds.id = try pds?.requireID()
  }

  init(
    cid: String, did: String, nullified: Bool, createdAt: Date
  ) throws {
    self.id = .init(cid: cid, did: did)
    self.nullified = nullified
    self.createdAt = createdAt
  }
}

extension Operation: MergeSort {
  typealias CompareValue = Date
  func compareValue() -> CompareValue {
    self.createdAt
  }
}

extension Operation: TreeSort {
  typealias KeyType = Operation.IDValue
  func cursor() throws -> KeyType {
    try self.requireID()
  }
  func previousCursor() -> KeyType? {
    self.$prev.id
  }
}

extension Array where Element == Operation {
  func onlyUpdateHandle() throws -> Self {
    var result: Self = []
    var previous: UUID?
    for operation in self {
      let handleId = operation.handle?.id
      if handleId != previous || previous == nil {
        result.append(operation)
      }
      previous = handleId
    }
    return result
  }
}

extension Operation {
  convenience init(exportedOp: ExportedOperation, prevOp: Operation? = nil, app: Application)
    async throws
  {
    try self.init(
      cid: exportedOp.cid, did: exportedOp.did, nullified: exportedOp.nullified,
      createdAt: exportedOp.createdAt)
    switch exportedOp.operation {
    case .create(let createOp):
      _ = try await (
        self.resolveDid(on: app.didRepository),
        self.resolve(handle: createOp.handle, on: app.handleRepository),
        self.resolve(serviceEndpoint: createOp.service, on: app.db)
      )
    case .plcOperation(let plcOp):
      guard
        let handleString = plcOp.alsoKnownAs.first(where: { $0.hasPrefix("at://") })?
          .replacingOccurrences(of: "at://", with: "")
      else {
        throw OpParseError.notFoundAtprotoHandle
      }
      _ = try await (
        self.resolve(handle: handleString, on: app.handleRepository),
        self.resolve(serviceEndpoint: plcOp.services.atprotoPds.endpoint, on: app.db),
        self.resolve(prevOp: prevOp, prevCid: plcOp.prev, app: app)
      )
    case .plcTombstone(let tombstoneOp):
      if let prevOp {
        try self.resolve(prev: prevOp)
      } else {
        try await self.resolve(prev: tombstoneOp.prev, on: app.db)
      }
    }
  }

  private func resolveDid(on repository: DidRepository) async throws {
    guard let did = self.id?.$did.id else {
      throw "not expected unset did"
    }
    try await repository.createIfNoxExists(did)
  }

  private func resolve(prevOp: Operation? = nil, prevCid: String? = nil, app: Application)
    async throws
  {
    if let prevOp {
      try self.resolve(prev: prevOp)
      return
    }
    if let prevCid {
      try await self.resolve(prev: prevCid, on: app.db)
      return
    }
    try await self.resolveDid(on: app.didRepository)
  }

  private func resolve(prev prevCid: String, on database: Database) async throws {
    guard let did = self.id?.$did.id,
      let prevOp = try await Operation.find(.init(cid: prevCid, did: did), on: database)
    else {
      throw OpParseError.unknownPreviousOp
    }
    try self.resolve(prev: prevOp)
  }

  private func resolve(prev prevOp: Operation) throws {
    let prevId = try prevOp.requireID()
    self.$prev.id = .init(cid: prevId.cid, did: prevId.$did.id)
  }

  private func resolve(handle handleName: String, on repository: HandleRepository) async throws {
    do {
      let handle = try await repository.createIfNoxExists(handleName)
      self.$handle.id = try handle.requireID()
    } catch HandleNameError.invalidCharacter {
      throw OpParseError.invalidHandle
    }
  }

  private func resolve(serviceEndpoint endpoint: String, on database: Database) async throws {
    if let pds = try await PersonalDataServer.query(on: database).filter(\.$endpoint == endpoint)
      .first()
    {
      self.$pds.id = try pds.requireID()
      return
    }
    let pds = PersonalDataServer(endpoint: endpoint)
    do {
      try await pds.create(on: database)
    } catch let error as PostgresError where error.code == .uniqueViolation {
      try await self.resolve(serviceEndpoint: endpoint, on: database)
      return
    }
    self.$pds.id = try pds.requireID()
  }
}
