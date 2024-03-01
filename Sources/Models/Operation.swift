import Fluent
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
