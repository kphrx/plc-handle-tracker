import Fluent
import Foundation
import Queues
import Vapor

struct PollingPlcServerExportJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    var after: String? = nil
    if let last = try await PollingHistory.query(on: app.db).sort(\.$insertedAt, .descending).with(\.$operation).first() {
      guard last.$operation.id != nil || last.isFailed else {
        return app.logger.warning("latest polling job not completed")
      }
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      after = dateFormatter.string(from: last.createdAt)
    }
    let exportedLog = try await fetchExportedLog(app, after: after)
    let pollingHistory = try await self.logToPollingHistory(app, log: exportedLog)
    try await app.queues.queue.dispatch(ImportExportedLogJob.self, .init(json: exportedLog, historyId: try pollingHistory.requireID()))
  }

  func fetchExportedLog(_ app: Application, after: String?) async throws -> String {
    var url: URI = "https://plc.directory/export"
    if let after {
      url.query = "after=\(after)"
    }
    let response = try await app.client.get(url)
    let decoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
    let jsonLines = try response.content.decode(String.self, using: decoder).split(separator: "\n")
    return "[\(jsonLines.joined(separator: ","))]"
  }

  func logToPollingHistory(_ app: Application, log: String) async throws -> PollingHistory {
    let decoder = try ContentConfiguration.global.requireDecoder(for: .json)
    let json = try decoder.decode([ExportedOperation].self, from: .init(string: log), headers: [:])
    guard let lastOp = json.last else {
      throw "Empty export"
    }
    let pollingHistory = try PollingHistory(cid: lastOp.cid, createdAt: lastOp.createdAt)
    try await pollingHistory.create(on: app.db)
    return pollingHistory
  }
}
