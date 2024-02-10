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
    let (exportedLog, lastCid, lastDate) = try await self.getExportedLog(
      app, after: payload.after, count: payload.count)
    for (_, ops) in exportedLog {
      try await app.queues.queue.dispatch(
        ImportExportedLogJob.self,
        .init(ops: ops, historyId: payload.historyId)
      )
    }
    try await self.log(to: payload.historyId, lastCid: lastCid, lastDate: lastDate, on: app.db)
  }

  private func getExportedLog(_ app: Application, after: Date?, count: UInt) async throws
    -> ([String: [String]], String?, Date?)
  {
    var (ops, bannedDids, nextCount, nextAfter) = (
      [String: [String]](), Set<String>(), count, after
    )
    var last: String?
    while true {
      let (exportedLog, dids, lastCid, lastDate) = try await self.fetchExportedLog(
        app.client, after: nextAfter, count: nextCount)
      ops.merge(exportedLog, uniquingKeysWith: { $0 + $1 })
      last = lastCid
      nextAfter = lastDate
      bannedDids.formUnion(dids)
      if nextCount <= 1000 || exportedLog.count < 1000 {
        break
      }
      nextCount -= 1000
      try await Task.sleep(nanoseconds: 1_000_000_000)
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
    return (ops, last, nextAfter)
  }

  private func fetchExportedLog(_ client: Client, after: Date?, count: UInt) async throws
    -> ([String: [String]], [String], String?, Date?)
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
    var (exportedLog, bannedDids) = ([String: [String]](), [String]())
    var lastDate: Date?
    var lastCid: String?
    for jsonLine in try response.content.decode(String.self, using: self.textDecoder).split(
      separator: "\n"
    ).map(String.init(_:)) {
      do {
        let exportedOp = try self.jsonDecoder.decode(
          ExportedOperation.self, from: .init(string: jsonLine), headers: [:])
        lastCid = exportedOp.cid
        lastDate = exportedOp.createdAt
        let did = exportedOp.did
        if bannedDids.contains(did) {
          continue
        }
        if exportedLog[did] == nil {
          exportedLog[did] = []
        }
        exportedLog[did]?.append(jsonLine)
      } catch OpParseError.notUsedInAtproto(let cid, let did, let createdAt) {
        lastCid = cid
        lastDate = createdAt
        bannedDids.append(did)
        exportedLog.removeValue(forKey: did)
      }
    }
    return (exportedLog, bannedDids, lastCid, lastDate)
  }

  private func log(to historyId: UUID, lastCid: String?, lastDate: Date?, on database: Database)
    async throws
  {
    guard let lastCid, let lastDate,
      let history = try await PollingHistory.find(historyId, on: database)
    else {
      throw "Empty export"
    }
    history.cid = lastCid
    history.createdAt = lastDate
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
