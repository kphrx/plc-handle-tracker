import Fluent
import Vapor

struct IndexContext: BaseContext {
  private(set) var title: String? = nil
  let route: String
  let latestImported: Date?
  let lastImport: Date?
}

func routes(_ app: Application) throws {
  app.get { req -> View in
    let latestPolling = try await PollingHistory.query(on: req.db).filter(\.$failed == false)
      .filter(\.$completed == true).sort(\.$insertedAt, .descending).field(\.$createdAt).field(
        \.$insertedAt
      ).first()
    return try await req.view.render(
      "index",
      IndexContext(
        route: req.route?.description ?? "", latestImported: latestPolling?.createdAt,
        lastImport: latestPolling?.insertedAt))
  }

  try app.register(collection: DidController())
  try app.register(collection: HandleController())
}
