import Fluent
import Vapor

final class PollingHistory: Model, Content {
  static let schema = "polling_history"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "cid")
  var cid: String

  @Children(for: \.$history)
  var statuses: [PollingJobStatus]

  @Field(key: "completed")
  var completed: Bool

  @Field(key: "failed")
  var failed: Bool

  @Timestamp(key: "created_at", on: .none)
  var createdAt: Date!

  @Timestamp(key: "inserted_at", on: .create)
  var insertedAt: Date!

  var running: Bool {
    get throws {
      if self.completed || self.failed {
        return false
      }
      guard self.$statuses.value != nil else {
        throw "require to load statuses children"
      }
      if self.statuses.isEmpty {
        return true
      }
      return self.statuses.contains(where: { $0.status == .queued || $0.status == .running })
    }
  }

  init() {}

  init(id: UUID? = nil, cid: String, createdAt: Date) {
    self.id = id
    self.cid = cid
    self.completed = false
    self.failed = false
    self.createdAt = createdAt
  }
}
