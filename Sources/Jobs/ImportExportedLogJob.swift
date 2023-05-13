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
    try await self.pollingCompleted(app, historyId: payload.historyId)
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

  private func pollingCompleted(_ app: Application, historyId: UUID) async throws {
    guard let last = try await PollingHistory.find(historyId, on: app.db) else {
      return
    }
    last.completed = true
    try await last.update(on: app.db)
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    app.logger.report(error: error)

    guard let last = try await PollingHistory.find(payload.historyId, on: app.db) else {
      return
    }
    last.failed = true
    try await last.update(on: app.db)
  }
}
