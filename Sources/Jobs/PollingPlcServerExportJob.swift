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
    ).with(
      \.$operation
    ).first() {
      guard last.$operation.id != nil else {
        return app.logger.warning("latest polling job not completed")
      }
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      after = dateFormatter.string(from: last.createdAt)
    }
    let (exportedLog, lastOp) = try await fetchExportedLog(app, after: after)
    let pollingHistory = try await self.logToPollingHistory(app, lastOp: lastOp)
    do {
      try await app.queues.queue.dispatch(
        ImportExportedLogJob.self,
        .init(json: exportedLog, historyId: try pollingHistory.requireID())
      )
    } catch {
      app.logger.report(error: error)
      pollingHistory.failed = true
      try await pollingHistory.save(on: app.db)
    }
  }

  private func fetchExportedLog(_ app: Application, after: String?) async throws
    -> (String, ExportedOperation?)
  {
    var url: URI = "https://plc.directory/export"
    if let after {
      url.query = "after=\(after)"
    }
    let response = try await app.client.get(url)
    let decoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
    let jsonLines = try response.content.decode(String.self, using: decoder).split(separator: "\n")
    let json = try jsonLines.last.map { lastOp throws in
      let decoder = try ContentConfiguration.global.requireDecoder(for: .json)
      return try decoder.decode(ExportedOperation.self, from: .init(string: String(lastOp)), headers: [:])
    }
    return ("[\(jsonLines.joined(separator: ","))]", json)
  }

  private func logToPollingHistory(_ app: Application, lastOp: ExportedOperation?) async throws
    -> PollingHistory
  {
    guard let lastOp else {
      throw "Empty export"
    }
    let pollingHistory = try PollingHistory(cid: lastOp.cid, createdAt: lastOp.createdAt)
    try await pollingHistory.create(on: app.db)
    return pollingHistory
  }
}
