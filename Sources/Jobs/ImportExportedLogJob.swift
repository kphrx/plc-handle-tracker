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
    try await app.db.transaction { transaction in
      try await self.insert(ops: payload.ops, on: transaction)
    }
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
      let exportedOp = payload.ops.first!
      let reason: BanReason =
        switch err {
        case .invalidHandle:
          .invalidHandle
        case .unknownPreviousOp:
          .missingHistory
        default:
          .incompatibleAtproto
        }
      if let did = try? await Did.find(exportedOp.did, on: app.db) {
        did.banned = true
        did.reason = reason
        try? await did.update(on: app.db)
      } else {
        try? await Did(exportedOp.did, banned: true, reason: reason).create(on: app.db)
      }
    }
    app.logger.report(error: error)
  }
}
