import Fluent
import Vapor

final class PollingHistory: Model, Content {
  static func getLatestWithoutErrors(on database: Database) async throws -> PollingHistory? {
    let errors = try await PollingJobStatus.query(on: database).filter(\.$status == .error)
      .all(\.$history.$id)
    return try await PollingHistory.query(on: database).filter(\.$failed == false).filter(
      \.$id !~ errors
    ).sort(\.$insertedAt, .descending).first()
  }

  static func getLatestCompleted(on database: Database) async throws -> PollingHistory? {
    let errorOrRunnings = try await PollingJobStatus.query(on: database).filter(
      \.$status != .success
    )
    .all(\.$history.$id)
    return try await PollingHistory.query(on: database).filter(\.$failed == false).filter(
      \.$cid != .null
    ).filter(\.$createdAt != .null).group(.or) {
      $0.filter(\.$completed == true).filter(\.$id !~ errorOrRunnings)
    }.sort(\.$insertedAt, .descending).first()
  }

  static let schema = "polling_history"

  @ID(key: .id)
  var id: UUID?

  @OptionalField(key: "cid")
  var cid: String?

  @Children(for: \.$history)
  var statuses: [PollingJobStatus]

  @Field(key: "completed")
  var completed: Bool

  @Field(key: "failed")
  var failed: Bool

  @Timestamp(key: "created_at", on: .none)
  var createdAt: Date?

  @Timestamp(key: "inserted_at", on: .create)
  var insertedAt: Date!

  init() {
    self.completed = false
    self.failed = false
  }

  init(id: UUID? = nil, cid: String, createdAt: Date) {
    self.id = id
    self.cid = cid
    self.completed = false
    self.failed = false
    self.createdAt = createdAt
  }

  func running(on database: Database) async throws -> Bool {
    if self.completed || self.failed {
      return false
    }
    if self.cid == nil || self.createdAt == nil {
      return true
    }
    if self.$statuses.value == nil {
      try await self.$statuses.load(on: database)
    }
    return self.statuses.contains(where: { $0.status == .queued || $0.status == .running })
  }
}
