import Fluent
import Vapor

enum BanReason: String, Codable {
  case incompatibleAtproto = "incompatible_atproto"
  case invalidHandle = "invalid_handle"
  case missingHistory = "missing_history"
}

final class Did: Model, Content {
  static let schema = "dids"

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
