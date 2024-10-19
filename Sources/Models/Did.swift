import Fluent
import Vapor

enum BanReason: String, Codable {
  case incompatibleAtproto = "incompatible_atproto"
  case invalidHandle = "invalid_handle"
  case missingHistory = "missing_history"
}

final class Did: Model, Content, @unchecked Sendable {
  static let schema = "dids"

  static func findWithOperations(_ id: Did.IDValue?, on db: Database) async throws -> Did? {
    guard let id, let did = try await Did.query(on: db).filter(\.$id == id).first() else {
      return nil
    }
    try await did.loadNonNullifiedOps(on: db)
    return did
  }

  @ID(custom: "did", generatedBy: .user)
  var id: String?

  @Field(key: "banned")
  var banned: Bool

  @OptionalEnum(key: "reason")
  var reason: BanReason?

  @Children(for: \.$id.$did)
  var operations: [Operation]

  private var operationsCache: [Operation]?

  var nonNullifiedOperations: [Operation] {
    guard let ops = self.operationsCache else {
      fatalError("not eager loaded: nonNullifiedOperations")
    }
    return ops
  }

  init() {}

  init(_ did: String, banned: Bool = false, reason: BanReason? = nil) {
    self.id = did
    self.banned = banned
    if banned {
      self.reason = reason ?? .incompatibleAtproto
    }
  }

  func loadNonNullifiedOps(on db: Database) async throws {
    self.operationsCache = try await Operation.query(on: db)
      .filter(\.$id.$did.$id == self.requireID()).filter(\.$nullified == false).all()
  }
}

extension Did {
  static func validate(did: String) -> Bool {
    guard did.hasPrefix("did:plc:") else {
      return false
    }
    let specificId = did.replacingOccurrences(of: "did:plc:", with: "")
    return
      if specificId.rangeOfCharacter(
        from: .init(charactersIn: "abcdefghijklmnopqrstuvwxyz234567").inverted) != nil
    {
      false
    } else {
      specificId.count >= 24
    }
  }
}
