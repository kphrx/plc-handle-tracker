import Fluent

struct CreatePersonalDataServersTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("personal_data_servers")
      .id()
      .field("endpoint", .string, .required)
      .unique(on: "endpoint")
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("personal_data_servers").delete()
  }
}
