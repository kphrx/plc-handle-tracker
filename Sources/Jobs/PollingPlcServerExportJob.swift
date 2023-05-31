import Fluent
import Foundation
import Queues
import Vapor

struct PollingPlcServerExportJob: AsyncJob {
  static func lastPolledDateWithoutFailure(on database: Database) async throws -> Date? {
    guard let last = try await PollingHistory.getLatestWithoutErrors(on: database) else {
      return nil
    }
    if try await last.running(on: database) {
      throw "latest polling job not completed"
    }
    return last.createdAt
  }

  struct Payload: Content {
    let after: Date?
    let count: UInt
    let historyId: UUID

    init(after: Date?, count: UInt = 1000, history: PollingHistory) throws {
      self.after = after
      self.count = count
      self.historyId = try history.requireID()
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
    for tree in try treeSort(exportedLog) {
      try await app.queues.queue.dispatch(
        ImportExportedLogJob.self,
        .init(ops: tree, historyId: payload.historyId)
      )
    }
    try await self.log(to: payload.historyId, lastOp: exportedLog.last, on: app.db)
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
    var bannedDids: [String] = []
    let ops = try jsonLines.compactMap { json in
      do {
        return try jsonDecoder.decode(
          ExportedOperation.self, from: .init(string: String(json)), headers: [:])
      } catch OpParseError.notUsedInAtproto(let did) {
        bannedDids.append(did)
        return nil
      }
    }
    for did in bannedDids {
      if let did = try await Did.find(did, on: app.db) {
        did.banned = true
        did.reason = .incompatibleAtproto
        try? await did.update(on: app.db)
        continue
      }
      try await Did(did, banned: true).create(on: app.db)
    }
    return ops
  }

  private func log(to historyId: UUID, lastOp: ExportedOperation?, on database: Database)
    async throws
  {
    guard let lastOp, let history = try await PollingHistory.find(historyId, on: database) else {
      throw "Empty export"
    }
    history.cid = lastOp.cid
    history.createdAt = lastOp.createdAt
    return try await history.update(on: database)
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    app.logger.report(error: error)
    guard let history = try await PollingHistory.find(payload.historyId, on: app.db) else {
      return
    }
    history.failed = true
    try await history.update(on: app.db)
  }
}
