import Fluent
import FluentSQL

struct ChangePrimaryKeyToNaturalKeyOfDidAndCid: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      try await transaction.schema("operations")
        .deleteConstraint(name: "operations_did_fkey")
        .updateField("did", .string)
        .update()
      if let sql = transaction as? SQLDatabase {
        try await sql.raw(
          """
          UPDATE operations AS o
          SET did = d.did
          FROM dids AS d
          WHERE o.did = d.id::text
          """
        )
        .run()
      } else {
        throw "not supported currently database"
      }
      try await transaction.schema("dids")
        .deleteField("id")
        .constraint(.constraint(.compositeIdentifier([.key("did")]), name: "dids_pkey"))
        .update()
      try await transaction.schema("operations")
        .foreignKey("did", references: "dids", "did", name: "operations_did_fkey")
        .update()
    }

    try await database.transaction { transaction in
      try await transaction.schema("operations")
        .deleteConstraint(name: "operations_prev_fkey")
        .updateField("prev", .string)
        .update()
      if let sql = transaction as? SQLDatabase {
        try await sql.raw(
          """
          UPDATE operations AS o1
          SET prev = o2.cid
          FROM operations AS o2
          WHERE o1.prev = o2.id::text
          """
        )
        .run()
      } else {
        throw "not supported currently database"
      }
      try await transaction.schema("operations")
        .deleteField("id")
        .constraint(.constraint(.compositeIdentifier([.key("cid")]), name: "operations_pkey"))
        .update()
      try await transaction.schema("operations")
        .foreignKey("prev", references: "operations", "cid", name: "operations_prev_fkey")
        .update()
    }
  }

  func revert(on database: Database) async throws {
    throw "Cannot revert from this point"
  }
}
