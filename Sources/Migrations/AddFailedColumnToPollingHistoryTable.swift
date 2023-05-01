import Fluent
import FluentPostgresDriver

struct AddFailedColumnToPollingHistoryTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_history")
      .field("failed", .bool)
      .update()
    if let postgres = database as? PostgresDatabase {
      try await postgres.simpleQuery("UPDATE polling_history SET failed = false")
      try await postgres.simpleQuery("ALTER TABLE polling_history ALTER COLUMN failed SET NOT NULL")
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
