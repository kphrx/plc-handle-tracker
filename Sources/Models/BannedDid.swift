import Fluent
import Vapor

enum BanReason: String, Codable {
  case incompatibleAtproto = "incompatible_atproto"
  case invalidHandle = "invalid_handle"
  case missingHistory = "missing_history"
}

final class BannedDid: Model, Content {
  static let schema = "banned_dids"

  @ID(custom: "did", generatedBy: .user)
  var id: String?

  @Enum(key: "reason")
  var reason: BanReason

  init() {}

  init(did: String) {
    self.id = did
    self.reason = .incompatibleAtproto
  }
}
