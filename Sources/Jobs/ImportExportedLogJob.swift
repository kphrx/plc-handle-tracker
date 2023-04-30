import Fluent
import Foundation
import Queues
import Vapor

struct ImportExportedLogJob: AsyncJob {
  typealias Payload = Date?

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    var url: URI = "https://plc.directory/export"
    if let payload {
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      url.query = "after=\(dateFormatter.string(from: payload))"
    }
    let app = context.application
    let response = try await app.client.get(url)
    let textDecoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
    let jsonDecoder = try ContentConfiguration.global.requireDecoder(for: .json)
    let jsonLines = try response.content.decode(String.self, using: textDecoder).split(separator: "\n").joined(separator: ",")
    let json = try jsonDecoder.decode(
      [ExportedOperation].self,
      from: .init(string: "[\(jsonLines)]"),
      headers: [:]
    )
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
