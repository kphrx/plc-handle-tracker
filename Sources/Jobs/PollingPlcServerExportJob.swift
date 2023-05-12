import Fluent
import Foundation
import Queues
import Vapor

struct PollingPlcServerExportJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    var after: String? = nil
    if let last = try await PollingHistory.query(on: app.db).filter(\.$failed == false).sort(
      \.$insertedAt, .descending
    ).first() {
      guard last.completed else {
        return app.logger.warning("latest polling job not completed")
      }
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      after = dateFormatter.string(from: last.createdAt)
    }
    let exportedLog = try await fetchExportedLog(app, after: after)
    let pollingHistory = try await self.logToPollingHistory(app, lastOp: exportedLog.last)
    do {
      try await app.queues.queue.dispatch(
        ImportExportedLogJob.self,
        .init(ops: exportedLog, historyId: try pollingHistory.requireID())
      )
    } catch {
      app.logger.report(error: error)
      pollingHistory.failed = true
      try await pollingHistory.save(on: app.db)
    }
  }

  private func fetchExportedLog(_ app: Application, after: String?) async throws
    -> [ExportedOperation]
  {
    var url: URI = "https://plc.directory/export"
    if let after {
      url.query = "after=\(after)"
    }
    let response = try await app.client.get(url)
    let textDecoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
    let jsonDecoder = try ContentConfiguration.global.requireDecoder(for: .json)
    let jsonLines = try response.content.decode(String.self, using: textDecoder).split(
      separator: "\n")
    return try jsonDecoder.decode(
      [ExportedOperation].self, from: .init(string: "[\(jsonLines.joined(separator: ","))]"),
      headers: [:])
  }

  private func logToPollingHistory(_ app: Application, lastOp: ExportedOperation?) async throws
    -> PollingHistory
  {
    guard let lastOp else {
      throw "Empty export"
    }
    let pollingHistory = PollingHistory(cid: lastOp.cid, createdAt: lastOp.createdAt)
    try await pollingHistory.create(on: app.db)
    return pollingHistory
  }
}
