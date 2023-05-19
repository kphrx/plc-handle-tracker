import Fluent

struct CreateBannedDidsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("banned_dids")
      .field("did", .string, .identifier(auto: false))
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("banned_dids").delete()
  }
}
