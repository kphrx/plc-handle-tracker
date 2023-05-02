import Fluent
import FluentSQL

struct AddCompletedColumnToPollingHistoryTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("polling_history")
      .field("completed", .bool)
      .update()
    try await database.transaction { transaction in
      if let sql = transaction as? SQLDatabase {
        try await sql.raw("UPDATE polling_history SET completed = true WHERE operation IS NOT NULL")
          .run()
        try await sql.raw("UPDATE polling_history SET completed = false WHERE operation IS NULL")
          .run()
        try await sql.raw("ALTER TABLE polling_history ALTER COLUMN completed SET NOT NULL").run()
      } else {
        throw "not supported currently database"
      }
    }
    try await database.schema("polling_history")
      .deleteField("operation")
      .update()
  }

  func revert(on database: Database) async throws {
    try await database.schema("polling_history")
      .field("operation", .uuid, .references("operations", "id"))
      .update()
    if let sql = database as? SQLDatabase {
      try await sql.raw(
        """
        UPDATE polling_history AS h
        SET operation = o.id
        FROM operations AS o
        WHERE
          h.completed = true
          AND h.cid = o.cid
        """
      ).run()
    } else {
      throw "not supported currently database"
    }
    try await database.schema("polling_history")
      .deleteField("completed")
      .update()
  }
}
