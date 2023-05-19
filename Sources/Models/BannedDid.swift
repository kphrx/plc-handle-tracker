import Fluent
import Vapor

final class BannedDid: Model, Content {
  static let schema = "banned_dids"

  @ID(custom: "did", generatedBy: .user)
  var id: String?

  init() {}

  init(did: String) {
    self.id = did
  }
}
