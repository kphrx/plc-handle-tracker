import Fluent
import FluentSQL

struct AddReasonColumnToBannedDidsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    let banReasonType = try await database.enum("ban_reason_type")
      .case("incompatible_atproto")
      .case("invalid_handle")
      .case("missing_history")
      .create()
    try await database.schema("banned_dids")
      .field("reason", banReasonType)
      .update()
    if let sql = database as? SQLDatabase {
      try await sql.update("banned_dids")
        .set("reason", to: "incompatible_atproto")
        .run()
      try await sql.raw("ALTER TABLE banned_dids ALTER COLUMN reason SET NOT NULL").run()
    } else {
      throw "not supported currently database"
    }
  }

  func revert(on database: Database) async throws {
    try await database.enum("ban_reason_type").delete()
    try await database.schema("banned_dids")
      .deleteField("reason")
      .update()
  }
}
