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
        group.addTask { try await self.insert(ops: tree, on: app.db) }
      }
    }
    try await self.pollingCompleted(app, historyId: payload.historyId)
  }

  private func insert(ops operations: [ExportedOperation], on database: Database) async throws {
    for exportedOp in operations {
      if try await Operation.find(exportedOp.cid, on: database) != nil {
        continue
      }
      let operation = try await exportedOp.normalize(on: database)
      try await operation.create(on: database)
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
