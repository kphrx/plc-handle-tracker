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
    let ops = try response.content.decode([ExportedOperation].self)
    try await app.db.transaction { transaction in
      try await self.insert(ops: ops, on: transaction)
    }
    try? await BannedDid.query(on: app.db).filter(\.$id == payload).delete()
    try? await PollingJobStatus.query(on: app.db).set(\.$status, to: .success).filter(
      \.$did == payload
    ).group(.or) { $0.filter(\.$status == .error).filter(\.$status == .banned) }.update()
  }

  private func insert(ops operations: [ExportedOperation], on database: Database) async throws {
    var prevOp: Operation?
    for exportedOp in operations {
      if let operation = try await Operation.find(exportedOp.cid, on: database) {
        prevOp = operation
        continue
      }
      let operation = try await exportedOp.normalize(prev: prevOp, on: database)
      try await operation.create(on: database)
      prevOp = operation
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
