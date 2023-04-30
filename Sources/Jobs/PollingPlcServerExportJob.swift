import Fluent
import Foundation
import Queues
import Vapor

struct PollingPlcServerExportJob: AsyncScheduledJob {
  func run(context: QueueContext) async throws {
    let app = context.application
    let last = try await PollingHistory.query(on: app.db).sort(\.$insertedAt, .descending).with(
      \.$operation
    ).first()
    let exportedLog = try await fetchExportedLog(app, last: last?.createdAt)
    async let importLog: () = app.queues.queue.dispatch(ImportExportedLogJob.self, exportedLog)
    async let updateHistory: () = self.updateHistory(app, last: last)
    try await importLog
    try await updateHistory
  }

  func fetchExportedLog(_ app: Application, last: Date?) async throws -> String {
    var url: URI = "https://plc.directory/export"
    if let last {
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      url.query = "after=\(dateFormatter.string(from: last))"
    }
    let response = try await app.client.get(url)
    let decoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
    let jsonLines = try response.content.decode(String.self, using: decoder).split(separator: "\n")
    return "[\(jsonLines.joined(separator: ","))]"
  }

  func updateHistory(_ app: Application, last: PollingHistory?) async throws {
    guard let last, last.$operation.id != nil else {
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
}
