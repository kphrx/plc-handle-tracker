import Fluent
import Vapor

final class Did: Model, Content {
  static let schema = "dids"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "did")
  var did: String

  @Children(for: \.$did)
  var operations: [Operation]

  init() {}

  init(id: UUID? = nil, did: String) {
    self.id = id
    self.did = did
  }
}
