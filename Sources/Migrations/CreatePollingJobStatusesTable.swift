import Fluent

struct CreatePollingJobStatusesTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_job_statuses")
      .id()
      .field("history_id", .uuid, .required, .references("polling_history", "id"))
      .field("status", .int16, .required)
      .field("queued_at", .datetime, .required)
      .field("dequeued_at", .datetime)
      .field("completed_at", .datetime)
      .field("created_at", .datetime, .required)
      .field("updated_at", .datetime, .required)
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("polling_job_statuses").delete()
  }
}
