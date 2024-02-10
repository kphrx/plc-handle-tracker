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

  private let jsonDecoder: ContentDecoder
  private let textDecoder: ContentDecoder

  init() throws {
    self.jsonDecoder = try ContentConfiguration.global.requireDecoder(for: .json)
    self.textDecoder = try ContentConfiguration.global.requireDecoder(for: .plainText)
  }

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    let app = context.application
    let exportedLog = try await self.getExportedLog(app, after: payload.after, count: payload.count)
    for (_, ops) in Dictionary(grouping: exportedLog, by: { $0.did }) {
      if ops.count == 1 {
        try await app.queues.queue.dispatch(
          ImportExportedLogJob.self,
          .init(ops: ops, historyId: payload.historyId)
        )
        continue
      }
      for tree in try treeSort(ops) {
        try await app.queues.queue.dispatch(
          ImportExportedLogJob.self,
          .init(ops: tree, historyId: payload.historyId)
        )
      }
    }
    try await self.log(to: payload.historyId, lastOp: exportedLog.last, on: app.db)
  }

  private func getExportedLog(_ app: Application, after: Date?, count: UInt) async throws
    -> [ExportedOperation]
  {
    var (ops, bannedDids, nextCount, nextAfter) = (
      [ExportedOperation](), Set<String>(), count, after
    )
    while true {
      let (exportedLog, dids, last) = try await self.fetchExportedLog(
        app.client, after: nextAfter, count: nextCount)
      ops += exportedLog
      bannedDids.formUnion(dids)
      if nextCount <= 1000 || exportedLog.count < 1000 {
        break
      }
      nextCount -= 1000
      nextAfter = last
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

  private func fetchExportedLog(_ client: Client, after: Date?, count: UInt) async throws
    -> ([ExportedOperation], [String], Date?)
  {
    var url: URI = "https://plc.directory/export"
    url.query =
      if let after = after.map({ date in
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.string(from: date)
      }) {
        "count=\(count)&after=\(after)"
      } else {
        "count=\(count)"
      }
    let response = try await client.get(url)
    var (jsonLines, bannedDids) = ([ExportedOperation](), [String]())
    var lastDate: Date?
    for jsonLine in try response.content.decode(String.self, using: self.textDecoder).split(
      separator: "\n"
    ).map(String.init(_:)) {
      do {
        let exportedOp = try self.jsonDecoder.decode(
          ExportedOperation.self, from: .init(string: jsonLine), headers: [:])
        lastDate = exportedOp.createdAt
        jsonLines.append(exportedOp)
      } catch OpParseError.notUsedInAtproto(let did, let createdAt) {
        lastDate = createdAt
        bannedDids.append(did)
      }
    }
    return (jsonLines, bannedDids, lastDate)
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
