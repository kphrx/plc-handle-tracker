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
    do {
      try await app.db.transaction { transaction in
        try await self.insert(ops: ops, on: transaction)
      }
    } catch let error as OpParseError {
      let exportedOp = ops.first!
      var reason = BanReason.incompatibleAtproto
      switch error {
      case .invalidHandle:
        reason = .invalidHandle
      case .unknownPreviousOp:
        reason = .missingHistory
      default:
        break
      }
      if let did = try? await Did.find(exportedOp.did, on: app.db) {
        did.banned = true
        did.reason = reason
        try? await did.update(on: app.db)
      } else {
        try? await Did(exportedOp.did, banned: true, reason: reason).create(on: app.db)
      }
      try? await PollingJobStatus.query(on: app.db).set(\.$status, to: .banned).filter(
        \.$did == payload
      ).filter(\.$status !~ [.success, .banned]).update()
      throw error
    }
    if let did = try? await Did.find(payload, on: app.db) {
      did.banned = false
      did.reason = nil
      try? await did.update(on: app.db)
    }
    try? await PollingJobStatus.query(on: app.db).set(\.$status, to: .success).filter(
      \.$did == payload
    ).filter(\.$status !~ [.success, .banned]).update()
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
