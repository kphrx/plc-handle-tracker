import Fluent

struct CreatePollingHistoryTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_history")
      .id()
      .field("operation", .uuid, .references("operations", "id"))
      .field("cid", .string, .required)
      .field("created_at", .datetime, .required)
      .field("inserted_at", .datetime, .required)
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("polling_history").delete()
  }
}
