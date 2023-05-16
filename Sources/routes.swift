import Fluent
import Vapor

struct IndexContext: BaseContext {
  private(set) var title: String?
  let route: String
  let latestImported: Date?
  let lastImport: Date?
}

func routes(_ app: Application) throws {
  app.get { req -> View in
    let completedIds = try await PollingJobStatus.query(on: req.db).filter(\.$status == .success)
      .all(\.$history.$id)
    let notCompletedIds = try await PollingJobStatus.query(on: req.db).filter(\.$status != .success)
      .all(\.$history.$id)
    let latestPolling = try await PollingHistory.query(on: req.db).filter(\.$failed == false).group(
      .or
    ) {
      $0.filter(\.$completed == true).group(.and) {
        $0.filter(\.$id !~ notCompletedIds).filter(\.$id ~~ completedIds)
      }
    }.sort(\.$insertedAt, .descending).field(\.$createdAt).field(\.$insertedAt).first()
    return try await req.view.render(
      "index",
      IndexContext(
        route: req.route?.description ?? "", latestImported: latestPolling?.createdAt,
        lastImport: latestPolling?.insertedAt))
  }

  try app.register(collection: DidController())
  try app.register(collection: HandleController())
}
