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
      if let operation = try await Operation.find(exportedOp.cid, on: database) {
        prevOp = operation
        continue
      }
      do {
        let operation = try await exportedOp.normalize(prev: prevOp, on: database)
        try await operation.create(on: database)
        prevOp = operation
      } catch let error as OpParseError {
        let bannedDid =
          try await BannedDid.find(exportedOp.did, on: database) ?? BannedDid(did: exportedOp.did)
        switch error {
        case .invalidHandle:
          bannedDid.reason = .invalidHandle
        case .unknownPreviousOp:
          bannedDid.reason = .missingHistory
        default:
          break
        }
        try? await bannedDid.create(on: database)
        return
      }
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
