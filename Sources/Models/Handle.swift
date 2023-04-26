import Fluent
import Vapor

final class Handle: Model, Content {
  static let schema = "handles"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "handle")
  var handle: String

  @Children(for: \.$handle)
  var operations: [Operation]

  init() {}

  init(id: UUID? = nil, handle: String) {
    self.id = id
    self.handle = handle
  }
}
