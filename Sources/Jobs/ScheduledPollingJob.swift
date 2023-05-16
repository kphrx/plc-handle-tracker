import Queues
import Vapor

struct ScheduledPollingJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    do {
      let after: Date? = try await PollingPlcServerExportJob.lastPolledDateWithoutFailure(
        on: app.db)
      try await app.queues.queue.dispatch(
        PollingPlcServerExportJob.self,
        .init(after: after)
      )
    } catch {
      app.logger.report(error: error)
    }
  }
}
