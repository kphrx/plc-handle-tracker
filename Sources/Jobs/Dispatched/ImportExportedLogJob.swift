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
      let operation = try await Operation(exportedOp: exportedOp, prevOp: prevOp, on: database)
      try await operation.create(on: database)
      prevOp = operation
    }
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
