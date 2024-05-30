import Fluent
import Vapor

enum BanReason: String, Codable {
  case incompatibleAtproto = "incompatible_atproto"
  case invalidHandle = "invalid_handle"
  case missingHistory = "missing_history"
}

final class Did: Model, Content, @unchecked Sendable {
  static let schema = "dids"

  static func findWithOperations(_ did: Did.IDValue?, on db: Database) async throws -> Did? {
    if let did {
      try await Did.query(on: db).filter(\.$id == did).with(\.$operations).first()
    } else {
      nil
    }
  }

  @ID(custom: "did", generatedBy: .user)
  var id: String?

  @Field(key: "banned")
  var banned: Bool

  @OptionalEnum(key: "reason")
  var reason: BanReason?

  @Children(for: \.$id.$did)
  var operations: [Operation]

  init() {}

  init(_ did: String, banned: Bool = false, reason: BanReason? = nil) {
    self.id = did
    self.banned = banned
    if banned {
      self.reason = reason ?? .incompatibleAtproto
    }
  }
}

extension Did {
  static func validate(did: String) -> Bool {
    if !did.hasPrefix("did:plc:") {
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
