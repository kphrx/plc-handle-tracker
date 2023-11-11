import Fluent
import Foundation
import Queues
import Vapor

struct FetchDidJob: AsyncJob {
  typealias Payload = String

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    if !validateDidPlaceholder(payload) {
      throw "Invalid DID Placeholder"
    }
    let app = context.application
    let res = try await app.client.send(.HEAD, to: "https://plc.directory/\(payload)")
    if 299 >= res.status.code {
      try await app.queues.queue.dispatch(ImportAuditableLogJob.self, payload)
    } else {
      app.logger.debug("Not found DID: \(payload), resCode: \(res.status.code)")
      throw "Not found"
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
