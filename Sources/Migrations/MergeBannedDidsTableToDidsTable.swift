import Fluent
import FluentSQL

struct MergeBannedDidsTableToDidsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      let banReason = try await transaction.enum("ban_reason").read()
      try await transaction.schema("dids")
        .field("banned", .bool, .required, .sql(.default(false)))
        .field("reason", banReason)
        .update()
      guard let sql = transaction as? SQLDatabase else {
        throw "not supported currently database"
      }
      for bannedDidRow in try await sql.select().columns("*").from("banned_dids").all() {
        let did = try bannedDidRow.decode(column: "did", as: String.self)
        let reason = try bannedDidRow.decode(column: "reason", as: BanReason.self)
        if let did = try await Did.find(did, on: transaction) {
          did.banned = true
          did.reason = reason
        } else {
          try await Did(did, banned: true, reason: reason).create(on: transaction)
        }
      }
    }
    try await database.schema("banned_dids").delete()
  }

  func revert(on database: Database) async throws {
    try await database.transaction { transaction in
      let banReason = try await transaction.enum("ban_reason").read()
      try await transaction.schema("banned_dids")
        .field("did", .string, .identifier(auto: false))
        .field("reason", banReason, .required, .custom("DEFAULT 'incompatible_atproto'"))
        .create()
      for bannedDids in try await Did.query(on: transaction).filter(\.$banned == true).all() {
        guard let sql = transaction as? SQLDatabase else {
          throw "not supported currently transaction"
        }
        try await sql.update("banned_dids")
          .set("did", to: SQLLiteral.string(try bannedDids.requireID()))
          .set(
            "reason", to: SQLLiteral.string((bannedDids.reason ?? .incompatibleAtproto).rawValue)
          )
          .run()
      }
      try await transaction.schema("dids")
        .deleteField("banned")
        .deleteField("reason")
        .update()
    }
  }
}
