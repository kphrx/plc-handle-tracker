import Foundation
import Vapor

enum OpParseError: Error {
  case notUsedInAtproto(String, Date)
  case notFoundAtprotoHandle
  case invalidHandle
  case unknownPreviousOp
}

enum CompatibleOperationOrTombstone: Encodable {
  case create(CreateOperation)
  case plcOperation(PlcOperation)
  case plcTombstone(PlcTombstone)

  func encode(to encoder: Encoder) throws {
    switch self {
      case .create(let createOp): try createOp.encode(to: encoder)
      case .plcOperation(let plcOp): try plcOp.encode(to: encoder)
      case .plcTombstone(let tombstoneOp): try tombstoneOp.encode(to: encoder)
    }
  }
}

enum OpType: String, Content {
  case create
  case plcOperation = "plc_operation"
  case plcTombstone = "plc_tombstone"
}

struct PlcOperation: Encodable {
  let sig: String
  var type: OpType { .plcOperation }
  let prev: String?

  let services: Services

  let alsoKnownAs: [String]
  let rotationKeys: [String]

  struct VerificationMethods: Content {
    let atproto: String
  }
  let verificationMethods: VerificationMethods

  private enum CodingKeys: String, CodingKey {
    case sig, type, prev, services, alsoKnownAs, rotationKeys, verificationMethods
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.sig, forKey: .sig)
    try container.encode(self.type, forKey: .type)
    try container.encode(self.prev, forKey: .prev)
    try container.encode(self.services, forKey: .services)
    try container.encode(self.alsoKnownAs, forKey: .alsoKnownAs)
    try container.encode(self.rotationKeys, forKey: .rotationKeys)
    try container.encode(self.verificationMethods, forKey: .verificationMethods)
  }
}
struct Services: Content {
  struct Service: Content {
    let type: String  // AtprotoPersonalDataServer
    let endpoint: String
  }
  let atprotoPds: Service

  private enum CodingKeys: String, CodingKey {
    case atprotoPds = "atproto_pds"
  }
}

struct CreateOperation: Encodable {
  let sig: String
  var type: OpType { .create }
  var prev: String? { nil }

  let handle: String
  let service: String
  let signingKey: String
  let recoveryKey: String

  private enum CodingKeys: String, CodingKey {
    case sig, type, prev, handle, service, signingKey, recoveryKey
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.sig, forKey: .sig)
    try container.encode(self.type, forKey: .type)
    try container.encode(self.prev, forKey: .prev)
    try container.encode(self.handle, forKey: .handle)
    try container.encode(self.service, forKey: .service)
    try container.encode(self.signingKey, forKey: .signingKey)
    try container.encode(self.recoveryKey, forKey: .recoveryKey)
  }
}

struct PlcTombstone: Encodable {
  let sig: String
  var type: OpType { .plcTombstone }
  let prev: String

  private enum CodingKeys: String, CodingKey {
    case sig, type, prev
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.sig, forKey: .sig)
    try container.encode(self.type, forKey: .type)
    try container.encode(self.prev, forKey: .prev)
  }
}

struct ExportedOperation: Content {
  var did: String
  var operation: CompatibleOperationOrTombstone
  var cid: String
  var nullified: Bool
  var createdAt: Date

  private struct GenericOperaion: Decodable {
    let sig: String
    let type: OpType
    let prev: String?

    let handle: String?
    let service: String?
    let signingKey: String?
    let recoveryKey: String?

    let services: [String: Services.Service]?
    let alsoKnownAs: [String]?
    let rotationKeys: [String]?
    let verificationMethods: [String: String]?
  }

  private enum CodingKeys: String, CodingKey {
    case did
    case operation
    case cid
    case nullified
    case createdAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.did = try container.decode(String.self, forKey: .did)
    self.cid = try container.decode(String.self, forKey: .cid)
    self.nullified = try container.decode(Bool.self, forKey: .nullified)
    self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    let operation = try container.decode(GenericOperaion.self, forKey: .operation)
    switch operation.type {
      case .create:
        self.operation = .create(
          .init(
            sig: operation.sig, handle: operation.handle!, service: operation.service!,
            signingKey: operation.signingKey!, recoveryKey: operation.recoveryKey!))
      case .plcOperation:
        guard let signingKey = operation.verificationMethods?["atproto"],
          let atprotoPds = operation.services?["atproto_pds"],
          atprotoPds.type == "AtprotoPersonalDataServer"
        else {
          throw OpParseError.notUsedInAtproto(self.did, self.createdAt)
        }
        self.operation = .plcOperation(
          .init(
            sig: operation.sig, prev: operation.prev, services: Services(atprotoPds: atprotoPds),
            alsoKnownAs: operation.alsoKnownAs!, rotationKeys: operation.rotationKeys!,
            verificationMethods: PlcOperation.VerificationMethods(atproto: signingKey)))
      case .plcTombstone:
        self.operation = .plcTombstone(.init(sig: operation.sig, prev: operation.prev!))
    }
  }
}

extension ExportedOperation: TreeSort {
  typealias KeyType = String
  func cursor() -> KeyType {
    self.cid
  }
  func previousCursor() -> KeyType? {
    switch self.operation {
      case .create: nil
      case .plcOperation(let plcOp): plcOp.prev
      case .plcTombstone(let tombstoneOp): tombstoneOp.prev
    }
  }
}

extension Array where Element == ExportedOperation {
  func insert(app: Application) async throws {
    let (updateOp, createOp) = try await self.toChangeOperation(app: app)
    try await app.db.transaction { transaction in
      for op in updateOp {
        try await op.update(on: transaction)
      }
      for op in createOp {
        try await op.create(on: transaction)
      }
    }
  }

  private func toChangeOperation(app: Application) async throws -> (
    nullify: [Operation], newOps: [Operation]
  ) {
    var nullifyOps: [Operation] = []
    var newOps: [Operation] = []
    var existOps: [Operation.IDValue: Operation] = [:]
    for exportedOp in self {
      if let operation = try await Operation.find(
        .init(cid: exportedOp.cid, did: exportedOp.did), on: app.db)
      {
        existOps[try operation.requireID()] = operation
        if operation.nullified != exportedOp.nullified {
          operation.nullified = exportedOp.nullified
          nullifyOps.append(operation)
        }
        continue
      }
      let prevOp: Operation? =
        switch exportedOp.operation {
          case .plcOperation(let op):
            if let prev = op.prev { existOps[.init(cid: prev, did: exportedOp.did)] } else { nil }
          case .plcTombstone(let op): existOps[.init(cid: op.prev, did: exportedOp.did)]
          default: nil
        }
      let operation = try await Operation(exportedOp: exportedOp, prevOp: prevOp, app: app)
      existOps[try operation.requireID()] = operation
      newOps.append(operation)
    }
    return (nullifyOps, newOps)
  }
}
