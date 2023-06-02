import Fluent
import FluentSQL

struct CreateIndexForForeignKeyOfOperationsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      if let sql = transaction as? SQLDatabase {
        try await sql.create(index: "operations_did_fkey_index")
          .on("operations")
          .column("did")
          .run()
        try await sql.create(index: "operations_prev_fkey_index")
          .on("operations")
          .column("prev_cid")
          .column("prev_did")
          .run()
        try await sql.create(index: "operations_handle_fkey_index")
          .on("operations")
          .column("handle")
          .run()
        try await sql.create(index: "operations_pds_fkey_index")
          .on("operations")
          .column("pds")
          .run()
      } else {
        throw "not supported currently database"
      }
    }
  }

  func revert(on database: Database) async throws {
    try await database.transaction { transaction in
      if let sql = transaction as? SQLDatabase {
        try await sql.drop(index: "operations_pds_fkey_index").run()
        try await sql.drop(index: "operations_handle_fkey_index").run()
        try await sql.drop(index: "operations_prev_fkey_index").run()
        try await sql.drop(index: "operations_did_fkey_index").run()
      } else {
        throw "not supported currently database"
      }
    }
  }
}
