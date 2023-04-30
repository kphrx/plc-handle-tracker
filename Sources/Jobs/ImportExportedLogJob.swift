import Fluent
import Foundation
import Queues
import Vapor

struct ImportExportedLogJob: AsyncJob {
  struct Payload: Content {
    let json: String
    let historyId: UUID
  }

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    let app = context.application
    let decoder = try ContentConfiguration.global.requireDecoder(for: .json)
    let json = try decoder.decode(
      [ExportedOperation].self, from: .init(string: payload.json), headers: [:])
    guard json.count > 0 else {
      throw "Empty export"
    }
    try await withThrowingTaskGroup(of: Void.self) { [self] group in
      for tree in try treeSort(json) {
        group.addTask { try await self.insert(ops: tree, on: app.db) }
      }
    }
    try await self.pollingCompleted(app, historyId: payload.historyId)
  }

  private func insert(ops operations: [ExportedOperation], on database: Database) async throws {
    for exportedOp in operations {
      if try await Operation.query(on: database).filter(\.$cid == exportedOp.cid).first() != nil {
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
    if let opId = try await Operation.query(on: app.db).filter(\.$cid == last.cid).first()?
      .requireID()
    {
      last.$operation.id = opId
      try await last.save(on: app.db)
    } else {
      app.logger.warning("latest polling not stored: \(last.cid) [\(last.id?.uuidString ?? "")]")
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    app.logger.report(error: error)

    guard let last = try await PollingHistory.find(payload.historyId, on: app.db) else {
      return
    }
    last.failed = true
    try await last.save(on: app.db)
  }
}
