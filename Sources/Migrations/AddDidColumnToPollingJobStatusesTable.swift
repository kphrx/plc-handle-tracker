import Fluent

struct AddDidColumnToPollingJobStatusesTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_job_statuses")
      .field("did", .string)
      .update()
  }

  func revert(on database: Database) async throws {
    try await database.schema("polling_job_statuses")
      .deleteField("did")
      .update()
  }
}
