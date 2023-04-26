import Fluent

struct CreateDidsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("dids")
      .id()
      .field("did", .string, .required)
      .unique(on: "did")
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("dids").delete()
  }
}
