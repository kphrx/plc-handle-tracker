import Queues
import Vapor

struct ScheduledPollingJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    do {
      let after = try await PollingPlcServerExportJob.lastPolledDateWithoutFailure(on: app.db)
      let history = PollingHistory()
      try await history.create(on: app.db)
      try await app.queues.queue.dispatch(
        PollingPlcServerExportJob.self,
        .init(after: after, history: history)
      )
    } catch {
      app.logger.report(error: error)
    }
  }
}
