import Fluent
import Queues

struct ScheduledPollingHistoryCleanupJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    do {
      try await PollingJobStatus.query(on: app.db).filter(\.$status ~~ [.success, .banned]).delete()
      let errorOrRunnings = try await PollingJobStatus.query(on: app.db).all(\.$history.$id)
      guard
        let insertedAt = try await PollingHistory.queryCompleted(on: app.db, errorOrRunnings)
          .sort(\.$insertedAt, .descending).range(5...).limit(1).all(\.$insertedAt).first
      else {
        return
      }
      try await PollingHistory.queryCompleted(on: app.db, errorOrRunnings)
        .filter(\.$insertedAt < insertedAt).delete()
    } catch {
      app.logger.report(error: error)
    }
  }
}
