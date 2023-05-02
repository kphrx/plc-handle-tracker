import Fluent
import FluentSQL

struct AddFailedColumnToPollingHistoryTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_history")
      .field("failed", .bool)
      .update()
    if let sql = database as? SQLDatabase {
      try await sql.raw("UPDATE polling_history SET failed = false").run()
      try await sql.raw("ALTER TABLE polling_history ALTER COLUMN failed SET NOT NULL").run()
    } else {
      throw "not supported currently database"
    }
  }

  func revert(on database: Database) async throws {
    try await database.schema("polling_history")
      .deleteField("failed")
      .update()
  }
}
