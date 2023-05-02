import Fluent
import Vapor

final class Did: Model, Content {
  static let schema = "dids"

  @ID(custom: "did", generatedBy: .user)
  var id: String?

  @Children(for: \.$did)
  var operations: [Operation]

  init() {}

  init(did: String) {
    self.id = did
  }
}
