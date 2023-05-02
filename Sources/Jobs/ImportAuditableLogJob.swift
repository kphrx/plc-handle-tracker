import Fluent
import Foundation
import Queues
import Vapor

struct ImportAuditableLogJob: AsyncJob {
  typealias Payload = String

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    if !validateDidPlaceholder(payload) {
      throw "Invalid DID Placeholder"
    }
    let app = context.application
    let response = try await app.client.get("https://plc.directory/\(payload)/log/audit")
    let json = try response.content.decode([ExportedOperation].self)
    for exportedOp in json {
      if try await Operation.find(exportedOp.cid, on: app.db) != nil {
        continue
      }
      let operation = try await exportedOp.normalize(on: app.db)
      try await operation.create(on: app.db)
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
