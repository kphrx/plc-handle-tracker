import Fluent
import Queues

struct ScheduledPollingHistoryCleanupJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    do {
      try await PollingJobStatus.query(on: app.db).filter(\.$status == .success).delete()
      let notSuccessful = try await PollingJobStatus.query(on: app.db).filter(\.$status != .success)
        .all(\.$history.$id)
      guard
        let insertedAt = try await PollingHistory.query(on: app.db).filter(\.$id !~ notSuccessful)
          .sort(\.$insertedAt, .descending).range(5...).limit(1).all(\.$insertedAt).first
      else {
        return
      }
      try await PollingHistory.query(on: app.db).filter(\.$id !~ notSuccessful).filter(
        \.$insertedAt < insertedAt
      ).delete()
    } catch {
      app.logger.report(error: error)
    }
  }
}
