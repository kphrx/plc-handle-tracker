import Fluent
import Vapor

final class PollingHistory: Model, Content {
  static let schema = "polling_history"

  @ID(key: .id)
  var id: UUID?

  @OptionalParent(key: "operation")
  var operation: Operation?

  @Field(key: "cid")
  var cid: String

  @OptionalField(key: "failed")
  var failed: Bool?
  var isFailed: Bool {
    self.failed ?? false
  }

  @Field(key: "created_at")
  var createdAt: Date

  @Timestamp(key: "inserted_at", on: .create)
  var insertedAt: Date?

  init() {}

  init(id: UUID? = nil, op operation: Operation? = nil, cid: String, createdAt: Date) throws {
    self.id = id
    self.$operation.id = try operation?.requireID()
    self.cid = cid
    self.failed = false
    self.createdAt = createdAt
  }
}
