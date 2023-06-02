import Fluent
import FluentSQL

struct SQLNotExistsExpression: SQLExpression {
  public let expr: any SQLExpression

  @inlinable
  public init(_ expr: any SQLExpression) {
    self.expr = expr
  }

  @inlinable
  public func serialize(to serializer: inout SQLSerializer) {
    serializer.statement {
      $0.append("NOT EXISTS", self.expr)
    }
  }
}

struct ChangePrimaryKeyToCompositeDidAndCid: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      try await transaction.schema("operations")
        .deleteConstraint(name: "operations_prev_fkey")
        .deleteConstraint(name: "operations_pkey")
        .deleteUnique(on: "cid")
        .update()
      try await transaction.schema("operations")
        .constraint(
          .constraint(.compositeIdentifier([.key("cid"), .key("did")]), name: "operations_pkey")
        )
        .update()
      if let sql = transaction as? SQLDatabase {
        let deletedOpRows = try await sql.delete(from: "operations")
          .where("prev", .isNot, SQLLiteral.null)
          .where(
            SQLNotExistsExpression(
              SQLGroupExpression(
                sql.select().from("operations", as: "o")
                  .where(
                    SQLColumn("did", table: "operations"), .equal, SQLColumn("did", table: "o")
                  )
                  .where(
                    SQLColumn("prev", table: "operations"), .equal, SQLColumn("cid", table: "o")
                  )
                  .query
              ))
          )
          .returning("did")
          .all()
        let deletedDids = Array(
          Set(try deletedOpRows.map { try $0.decode(column: "did", as: String.self) }))
        if !deletedDids.isEmpty {
          try await sql.delete(from: "operations").where("did", .in, deletedDids).run()
          try await Did.query(on: transaction).set(\.$banned, to: true).set(
            \.$reason, to: .missingHistory
          ).filter(\.$id ~~ deletedDids).update()
        }
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

  func revert(on database: Database) async throws {
    try await database.transaction { transaction in
      try await transaction.schema("operations")
        .deleteConstraint(name: "operations_prev_fkey")
        .deleteConstraint(name: "operations_pkey")
        .update()
      try await transaction.schema("operations")
        .unique(on: "cid")
        .constraint(.constraint(.compositeIdentifier([.key("cid")]), name: "operations_pkey"))
        .foreignKey("prev", references: "operations", "cid", name: "operations_prev_fkey")
        .update()
    }
  }
}
