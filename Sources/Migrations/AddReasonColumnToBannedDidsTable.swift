import Fluent

struct AddReasonColumnToBannedDidsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    let banReason = try await database.enum("ban_reason")
      .case("incompatible_atproto")
      .case("invalid_handle")
      .case("missing_history")
      .create()
    try await database.schema("banned_dids")
      .field("reason", banReason, .required, .custom("DEFAULT 'incompatible_atproto'"))
      .update()
  }

  func revert(on database: Database) async throws {
    try await database.schema("banned_dids")
      .deleteField("reason")
      .update()
    try await database.enum("ban_reason").delete()
  }
}
