import Fluent
import Vapor

func routes(_ app: Application) throws {
  app.get { req -> View in
    let latestPolling = try await PollingHistory.query(on: req.db).filter(\.$failed == false)
      .filter(\.$completed == true).sort(\.$insertedAt, .descending).field(\.$createdAt).field(
        \.$insertedAt
      ).first()
    return try await req.view.render(
      "index",
      ["latestImported": latestPolling?.createdAt, "lastImport": latestPolling?.insertedAt])
  }

  try app.register(collection: DidController())
  try app.register(collection: HandleController())
}
