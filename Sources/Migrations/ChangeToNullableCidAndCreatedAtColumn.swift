import Fluent
import FluentSQL

struct ChangeToNullableCidAndCreatedAtColumn: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      if let sql = transaction as? SQLDatabase {
        try await sql.raw("ALTER TABLE polling_history ALTER COLUMN cid DROP NOT NULL").run()
        try await sql.raw("ALTER TABLE polling_history ALTER COLUMN created_at DROP NOT NULL").run()
      } else {
        throw "not supported currently database"
      }
    }
  }

  func revert(on database: Database) async throws {
    try await database.transaction { transaction in
      if let sql = transaction as? SQLDatabase {
        try await sql.raw("ALTER TABLE polling_history ALTER COLUMN cid SET NOT NULL").run()
        try await sql.raw("ALTER TABLE polling_history ALTER COLUMN created_at SET NOT NULL").run()
      } else {
        throw "not supported currently database"
      }
    }
  }
}
