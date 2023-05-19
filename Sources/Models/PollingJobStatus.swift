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

  @OptionalField(key: "did")
  var did: String?

  @Timestamp(key: "queued_at", on: .none)
  var queuedAt: Date!

  @Timestamp(key: "dequeued_at", on: .none)
  var dequeuedAt: Date?

  @Timestamp(key: "completed_at", on: .none)
  var completedAt: Date?

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date!

  @Timestamp(key: "updated_at", on: .update)
  var updatedAt: Date!

  enum Status: Int16, CaseIterable, Codable {
    case queued, running, success, error, banned
  }

  init() {}

  init(id uuid: UUID, historyId: UUID, did: String?, dispatchTimestamp queuedAt: Date) {
    self.id = uuid
    self.$history.id = historyId
    self.did = did
    self.status = .queued
    self.queuedAt = queuedAt
  }
}
