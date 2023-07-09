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
    if let did = try? await Did.find(payload, on: app.db) {
      did.banned = false
      did.reason = nil
      try? await did.update(on: app.db)
    }
    try? await PollingJobStatus.query(on: app.db).set(\.$status, to: .success).filter(
      \.$status != .success
    ).filter(\.$did == payload).update()
  }

  private func insert(ops operations: [ExportedOperation], on database: Database) async throws {
    var prevOp: Operation?
    for exportedOp in operations {
      if let operation = try await Operation.find(
        .init(cid: exportedOp.cid, did: exportedOp.did), on: database)
      {
        prevOp = operation
        continue
      }
      let operation = try await exportedOp.normalize(prev: prevOp, on: database)
      try await operation.create(on: database)
      prevOp = operation
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    if let err = error as? OpParseError {
      var reason: BanReason
      switch err {
      case .invalidHandle:
        reason = .invalidHandle
      case .unknownPreviousOp:
        reason = .missingHistory
      default:
        reason = .incompatibleAtproto
      }
      if let did = try? await Did.find(payload, on: app.db) {
        did.banned = true
        did.reason = reason
        try? await did.update(on: app.db)
      } else {
        try? await Did(payload, banned: true, reason: reason).create(on: app.db)
      }
      try? await PollingJobStatus.query(on: app.db).set(\.$status, to: .banned).filter(
        \.$status != .banned
      ).filter(\.$did == payload).update()
    }
    app.logger.report(error: error)
  }
}
