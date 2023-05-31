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
        var reason = BanReason.incompatibleAtproto
        switch error {
        case .invalidHandle:
          reason = .invalidHandle
        case .unknownPreviousOp:
          reason = .missingHistory
        default:
          break
        }
        if let did = try? await Did.find(exportedOp.did, on: database) {
          did.banned = true
          did.reason = reason
          try? await did.update(on: database)
          throw error
        }
        try? await Did(exportedOp.did, banned: true, reason: reason).create(on: database)
        throw error
      }
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
