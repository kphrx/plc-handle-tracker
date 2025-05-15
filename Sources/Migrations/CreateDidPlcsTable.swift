import Fluent

struct CreateDidPlcsTable: AsyncMigration {
  func prepare(on database: Database) async throws {
    try await database.transaction { transaction in
      let banReason = try await transaction.enum("ban_reason").read()
      try await transaction.schema("did_plcs")
        .field("id", .custom("BIT(120)"), .identifier(auto: false))
        .field("banned", .bool, .required, .sql(.default(false)))
        .field("reason", banReason)
        .create()

      var lastID: String? = nil
      while true {
        let query = Did.query(on: transaction).sort(\.$id).limit(64)
        if let lastID {
          query.filter(\.$id > lastID)
        }
        let dids = try await query.all()
        if dids.isEmpty { break }
        for did in dids {
          try await DidPlc(
            .init(didString: did.requireID()), banned: did.banned, reason: did.reason
          )
          .create(on: transaction)
        }
        lastID = dids.last?.id
      }
    }
  }

  func revert(on database: Database) async throws {
    try await database.schema("did_plcs").delete()
  }
}
