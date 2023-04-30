import Fluent
import Foundation
import Queues
import Vapor

struct PollingPlcServerExportJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    guard let last = try await PollingHistory.query(on: app.db).sort(\.$insertedAt, .descending).with(\.$operation).first() else {
      return try await app.queues.queue.dispatch(ImportExportedLogJob.self, nil)
    }
    async let importLog: () = app.queues.queue.dispatch(ImportExportedLogJob.self, last.createdAt)
    if last.$operation.id == nil {
      if let opId = try await Operation.query(on: app.db).filter(\.$cid == last.cid).first()?.requireID() {
        last.$operation.id = opId
        try await last.save(on: app.db)
      } else {
        app.logger.warning("latest polling not stored: \(last.cid) [\(last.id?.uuidString ?? "")]")
      }
    }
    return try await importLog
  }
}