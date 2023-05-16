import Fluent
import Foundation
import Queues
import Vapor

struct PollingPlcServerExportJob: AsyncJob {
  static func lastPolledDateWithoutFailure(on database: Database) async throws -> Date? {
    guard
      let last = try await PollingHistory.query(on: database).filter(\.$failed == false).sort(
        \.$insertedAt, .descending
      ).first()
    else {
      return nil
    }
    guard last.completed else {
      throw "latest polling job not completed"
    }
    return last.createdAt
  }

  struct Payload: Content {
    let after: Date?
    let count: UInt

    init(after: Date?, count: UInt = 1000) {
      self.after = after
      self.count = count
    }
  }

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    let app = context.application
    let after: String? = payload.after.map { date in
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return dateFormatter.string(from: date)
    }
    let exportedLog = try await fetchExportedLog(app, after: after, count: payload.count)
    let pollingHistory = try await self.logToPollingHistory(lastOp: exportedLog.last, on: app.db)
    do {
      try await app.queues.queue.dispatch(
        ImportExportedLogJob.self,
        .init(ops: exportedLog, historyId: try pollingHistory.requireID())
      )
    } catch {
      pollingHistory.failed = true
      try await pollingHistory.save(on: app.db)
      throw error
    }
  }

  private func fetchExportedLog(_ app: Application, after: String?, count: UInt) async throws
    -> [ExportedOperation]
  {
    var url: URI = "https://plc.directory/export"
    if let after {
      url.query = "count=\(count)&after=\(after)"
    } else {
      url.query = "count=\(count)"
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

  private func logToPollingHistory(lastOp: ExportedOperation?, on database: Database) async throws
    -> PollingHistory
  {
    guard let lastOp else {
      throw "Empty export"
    }
    let pollingHistory = PollingHistory(cid: lastOp.cid, createdAt: lastOp.createdAt)
    try await pollingHistory.create(on: database)
    return pollingHistory
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    context.application.logger.report(error: error)
  }
}
