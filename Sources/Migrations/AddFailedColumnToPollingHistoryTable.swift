import Fluent

struct AddFailedColumnToPollingHistoryTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_history")
      .field("failed", .bool, .required, .custom("DEFAULT false"))
      .update()
  }

  func revert(on database: Database) async throws {
    try await database.schema("polling_history")
      .deleteField("failed")
      .update()
  }
}
