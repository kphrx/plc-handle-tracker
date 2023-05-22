import Fluent
import Queues

struct ScheduledPollingRecoveryJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    do {
      let notSuccessful = try await PollingJobStatus.query(on: app.db).filter(\.$did != .null)
        .filter(\.$status !~ [.success, .banned]).unique().all(\.$did)
      for did in notSuccessful {
        try await app.queues.queue.dispatch(ImportAuditableLogJob.self, did!)
      }
    } catch {
      app.logger.report(error: error)
    }
  }
}
