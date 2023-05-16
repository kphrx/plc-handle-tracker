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
    try await withThrowingTaskGroup(of: Void.self) { [self] group in
      for tree in try treeSort(payload.ops) {
        group.addTask {
          try await app.db.transaction { transaction in
            try await self.insert(ops: tree, on: transaction)
          }
        }
      }
    }
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
