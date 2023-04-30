import Fluent
import Foundation
import Vapor

struct ImportExportLogCommand: AsyncCommand {
  struct Signature: CommandSignature {}

  var help: String {
    "Import from https://plc.directory/export"
  }

  func run(using context: CommandContext, signature: Signature) async throws {
    let app = context.application
    let last = try await PollingHistory.query(on: app.db).sort(\.$insertedAt, .descending).with(
      \.$operation
    ).first()
    let after = last.map { lastOp in
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return dateFormatter.string(from: lastOp.createdAt)
    }
    let exportedLog = try await fetchExportedLog(app, after: after)
    async let importLog: () = app.queues.queue.dispatch(ImportExportedLogJob.self, exportedLog)
    async let updateHistory: () = self.updateHistory(app, last: last)
    try await importLog
    try await updateHistory
    if let after {
      context.console.print("Queued fetching export log, after \(after)")
    } else {
      context.console.print("Queued fetching export log")
    }
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
