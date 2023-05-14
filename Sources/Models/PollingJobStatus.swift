import Fluent
import Vapor

final class PollingJobStatus: Model, Content {
  static let schema = "polling_job_statuses"

  @ID(custom: .id, generatedBy: .user)
  var id: UUID?

  @Parent(key: "history_id")
  var history: PollingHistory

  @Field(key: "status")
  var status: Status

  @Field(key: "queued_at")
  var queuedAt: Date

  @OptionalField(key: "dequeued_at")
  var dequeuedAt: Date?

  @OptionalField(key: "completed_at")
  var completedAt: Date?

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  @Timestamp(key: "updated_at", on: .update)
  var updatedAt: Date?

  enum Status: Int16, CaseIterable, Codable {
    case queued, running, success, error
  }

  init() {}

  init(id uuid: UUID, historyId: UUID, dispatchTimestamp queuedAt: Date) {
    self.id = uuid
    self.$history.id = historyId
    self.status = .queued
    self.queuedAt = queuedAt
  }
}
