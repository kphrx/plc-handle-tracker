import Fluent

struct CreateFetchDidJobStatusesTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("fetch_did_job_statuses")
      .id()
      .field("did", .string, .required)
      .field("status", .int16, .required)
      .field("queued_at", .datetime, .required)
      .field("dequeued_at", .datetime)
      .field("completed_at", .datetime)
      .field("created_at", .datetime, .required)
      .field("updated_at", .datetime, .required)
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("fetch_did_job_statuses").delete()
  }
}
