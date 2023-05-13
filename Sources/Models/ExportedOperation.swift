import Fluent
import FluentPostgresDriver
import Foundation
import Vapor

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
  var type: OpType { return .plcOperation }
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
  struct AtprotoPds: Content {
    private(set) var type: String = "AtprotoPersonalDataServer"
    let endpoint: String
  }
  let atprotoPds: AtprotoPds

  private enum CodingKeys: String, CodingKey {
    case atprotoPds = "atproto_pds"
  }
}

struct CreateOperation: Encodable {
  let sig: String
  var type: OpType { return .create }
  var prev: String? { return nil }

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
  var type: OpType { return .plcTombstone }
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

    let services: Services?
    let alsoKnownAs: [String]?
    let rotationKeys: [String]?
    let verificationMethods: PlcOperation.VerificationMethods?
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
    self.operation = {
      switch operation.type {
      case .create:
        return .create(
          .init(
            sig: operation.sig, handle: operation.handle!, service: operation.service!,
            signingKey: operation.signingKey!, recoveryKey: operation.recoveryKey!))
      case .plcOperation:
        return .plcOperation(
          .init(
            sig: operation.sig, prev: operation.prev, services: operation.services!,
            alsoKnownAs: operation.alsoKnownAs!, rotationKeys: operation.rotationKeys!,
            verificationMethods: operation.verificationMethods!))
      case .plcTombstone: return .plcTombstone(.init(sig: operation.sig, prev: operation.prev!))
      }
    }()
  }

  func normalize(prev prevOp: Operation? = nil, on database: Database) async throws -> Operation {
    switch self.operation {
    case .create(let createOp):
      async let handle = self.resolve(handle: createOp.handle, on: database)
      async let pds = self.resolve(serviceEndpoint: createOp.service, on: database)
      try await self.create(did: self.did, on: database)
      return try Operation(
        cid: self.cid, did: self.did, nullified: self.nullified,
        createdAt: self.createdAt, handle: try await handle, pds: try await pds)
    case .plcOperation(let plcOp):
      guard
        let handleString = plcOp.alsoKnownAs.first(where: { $0.hasPrefix("at://") })?
          .replacingOccurrences(of: "at://", with: "")
      else {
        throw "Not found handle"
      }
      async let handle = self.resolve(handle: handleString, on: database)
      async let pds = self.resolve(
        serviceEndpoint: plcOp.services.atprotoPds.endpoint, on: database)
      let prev: Operation?
      if let prevOp {
        prev = prevOp
      } else {
        switch plcOp.prev {
        case .some(let cid): prev = try await self.resolve(prev: cid, on: database)
        case .none:
          try await self.create(did: self.did, on: database)
          prev = nil
        }
      }
      return try Operation(
        cid: self.cid, did: self.did, nullified: self.nullified, createdAt: self.createdAt, prev: prev,
        handle: try await handle, pds: try await pds)
    case .plcTombstone(let tombstoneOp):
      let prev: Operation
      if let prevOp {
        prev = prevOp
      } else {
        prev = try await self.resolve(prev: tombstoneOp.prev, on: database)
      }
      return try Operation(
        cid: self.cid, did: self.did, nullified: self.nullified,
        createdAt: self.createdAt, prev: prev)
    }
  }

  private func create(did string: String, on database: Database) async throws {
    if try await Did.find(string, on: database) != nil {
      return
    }
    do {
      try await Did(did: string).create(on: database)
    } catch let error as PostgresError where error.code == .uniqueViolation {
      return
    } catch {
      throw error
    }
  }

  private func resolve(handle string: String, on database: Database) async throws -> Handle {
    guard let handle = try await Handle.query(on: database).filter(\.$handle == string).first()
    else {
      let handle = Handle(handle: string)
      do {
        try await handle.create(on: database)
      } catch let error as PostgresError where error.code == .uniqueViolation {
        return try await self.resolve(handle: string, on: database)
      } catch {
        throw error
      }
      return handle
    }
    return handle
  }

  private func resolve(serviceEndpoint string: String, on database: Database) async throws
    -> PersonalDataServer
  {
    guard
      let service = try await PersonalDataServer.query(on: database).filter(\.$endpoint == string)
        .first()
    else {
      let service = PersonalDataServer(endpoint: string)
      do {
        try await service.create(on: database)
      } catch let error as PostgresError where error.code == .uniqueViolation {
        return try await self.resolve(serviceEndpoint: string, on: database)
      } catch {
        throw error
      }
      return service
    }
    return service
  }

  private func resolve(prev cid: String, on database: Database) async throws -> Operation {
    guard let operation = try await Operation.find(cid, on: database) else {
      throw "Unknown operation"
    }
    return operation
  }
}
