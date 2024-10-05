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
    let exportedLog = try await getExportedLog(app, after: payload.after, count: payload.count)
    for tree in try exportedLog.treeSort() {
      try await app.queues.queue.dispatch(
        ImportExportedLogJob.self,
        .init(ops: tree, historyId: payload.historyId)
      )
    }
    try await self.log(to: payload.historyId, lastOp: exportedLog.last, on: app.db)
  }

  private func getExportedLog(_ app: Application, after: Date?, count: UInt) async throws
    -> [ExportedOperation]
  {
    let jsonLines = try await self.fetchExportedLog(app.client, after: after, count: count)
    let jsonDecoder = try ContentConfiguration.global.requireDecoder(for: .json)
    var bannedDids: [String] = []
    let ops = try jsonLines.compactMap { json in
      do {
        return try jsonDecoder.decode(
          ExportedOperation.self, from: .init(string: String(json)), headers: [:])
      } catch OpParseError.notUsedInAtproto(let did, _) {
        bannedDids.append(did)
        return nil
      }
    }
    try await app.didRepository.ban(dids: bannedDids)
    return ops
  }

  private func fetchExportedLog(_ client: Client, after: Date?, count: UInt) async throws
    -> [String.SubSequence]
  {
    var url: URI = "https://plc.directory/export"
    url.query =
      if let after = after.map({ date in
        return date.formatted(
          .iso8601.dateSeparator(.dash).year().month().day().timeZone(separator: .colon).time(
            includingFractionalSeconds: true
          ).timeSeparator(.colon))
      }) {
        "count=\(count)&after=\(after)"
      } else {
        "count=\(count)"
      }
    let response = try await client.get(url)
    let textDecoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
    let jsonLines = try response.content.decode(String.self, using: textDecoder).split(
      separator: "\n")
    if count <= 1000 || jsonLines.count < 1000 {
      return jsonLines
    }
    let jsonDecoder = try ContentConfiguration.global.requireDecoder(for: .json)
    var nextAfter: Date?
    do {
      let lastOp = try jsonDecoder.decode(
        ExportedOperation.self, from: .init(string: String(jsonLines.last!)), headers: [:])
      nextAfter = lastOp.createdAt
    } catch OpParseError.notUsedInAtproto(_, let createdAt) {
      nextAfter = createdAt
    }
    let nextJsonLines = try await self.fetchExportedLog(
      client, after: nextAfter, count: count - 1000)
    return jsonLines + nextJsonLines
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
