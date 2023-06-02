import Fluent
import FluentSQL

struct AddPrevDidColumnForPrevForeignKey: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      try await transaction.schema("operations")
        .deleteConstraint(name: "operations_prev_fkey")
        .field("prev_did", .string)
        .update()
      if let sql = transaction as? SQLDatabase {
        try await sql.raw("ALTER TABLE operations RENAME COLUMN prev TO prev_cid").run()
        try await sql.raw(
          """
          UPDATE operations
          SET prev_did = did
          WHERE prev_cid IS NOT NULL
          """
        ).run()
      } else {
        throw "not supported currently database"
      }
      let checkBothNull = SQLTableConstraintAlgorithm.check(
        SQLBinaryExpression(
          SQLBinaryExpression(
            SQLBinaryExpression(SQLIdentifier("prev_cid"), .is, SQLLiteral.null),
            .and,
            SQLBinaryExpression(SQLIdentifier("prev_did"), .is, SQLLiteral.null)),
          .or,
          SQLBinaryExpression(
            SQLBinaryExpression(SQLIdentifier("prev_cid"), .isNot, SQLLiteral.null),
            .and,
            SQLBinaryExpression(SQLIdentifier("prev_did"), .isNot, SQLLiteral.null))
        ))
      try await transaction.schema("operations")
        .foreignKey(
          ["prev_cid", "prev_did"], references: "operations", ["cid", "did"],
          name: "operations_prev_fkey"
        )
        .constraint(.constraint(.sql(checkBothNull), name: "operations_prev_fkey_check"))
        .update()
    }
  }

  func revert(on database: Database) async throws {
    try await database.transaction { transaction in
      try await transaction.schema("operations")
        .deleteConstraint(name: "operations_prev_fkey")
        .deleteConstraint(name: "operations_prev_fkey_check")
        .update()
      try await transaction.schema("operations")
        .deleteField("prev_did")
        .update()
      if let sql = transaction as? SQLDatabase {
        try await sql.raw("ALTER TABLE operations RENAME COLUMN prev_cid TO prev").run()
      } else {
        throw "not supported currently database"
      }
      try await transaction.schema("operations")
        .foreignKey(
          ["prev", "did"], references: "operations", ["cid", "did"], name: "operations_prev_fkey"
        )
        .update()
    }
  }
}
