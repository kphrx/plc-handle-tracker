import Fluent

struct CreateHandlesTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("handles")
      .id()
      .field("handle", .string, .required)
      .unique(on: "handle")
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("handles").delete()
  }
}
