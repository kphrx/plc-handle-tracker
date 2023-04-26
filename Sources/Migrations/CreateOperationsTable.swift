import Fluent

struct CreateOperationsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.schema("operations")
      .id()
      .field("cid", .string, .required)
      .field("did", .uuid, .required, .references("dids", "id"))
      .field("nullified", .bool, .required)
      .field("created_at", .datetime, .required)
      .field("prev", .uuid, .references("operations", "id"))
      .field("handle", .uuid, .references("handles", "id"))
      .field("pds", .uuid, .references("personal_data_servers", "id"))
      .unique(on: "cid")
      .create()
  }

  func revert(on database: Database) async throws {
    try await database.schema("operations").delete()
  }
}
