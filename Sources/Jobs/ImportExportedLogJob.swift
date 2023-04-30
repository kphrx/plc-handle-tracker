import Fluent
import Foundation
import Queues
import Vapor

struct ImportExportedLogJob: AsyncJob {
  typealias Payload = String

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    let app = context.application
    let decoder = try ContentConfiguration.global.requireDecoder(for: .json)
    let json = try decoder.decode(
      [ExportedOperation].self, from: .init(string: payload), headers: [:])
    guard let lastOp = json.last else {
      throw "Empty export"
    }
    try await withThrowingTaskGroup(of: Void.self) { [self] group in
      group.addTask {
        try await PollingHistory(cid: lastOp.cid, createdAt: lastOp.createdAt).create(on: app.db)
      }
      for tree in try treeSort(json) {
        group.addTask { try await insert(ops: tree, on: app.db) }
      }
    }
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

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
