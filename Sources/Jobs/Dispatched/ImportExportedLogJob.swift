import Fluent
import Foundation
import Queues
import Vapor

struct ImportExportedLogJob: AsyncJob {
  struct Payload: Content {
    let ops: [ExportedOperation]
    let historyId: UUID
  }

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    let app = context.application
    if payload.ops.isEmpty {
      throw "Empty export"
    }
    try await payload.ops.insert(app: app)
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    app.logger.report(error: error)
    guard let err = error as? OpParseError, let op = payload.ops.first else {
      return
    }
    do {
      try await app.didRepository.ban(op.did, error: err)
    } catch {
      app.logger.report(error: error)
    }
  }
}
