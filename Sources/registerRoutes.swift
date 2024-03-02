import Fluent
import Vapor

struct IndexContext: BaseContext {
  private(set) var title: String?
  let route: String
  let latestPolling: PollingHistory?
}

func registerRoutes(_ app: Application) throws {
  app.get { req -> View in
    try await req.view.render(
      "index",
      IndexContext(
        route: req.route?.description ?? "",
        latestPolling: try await PollingHistory.getLatestCompleted(on: req.db)))
  }

  try app.register(collection: DidController())
  try app.register(collection: HandleController())
}
