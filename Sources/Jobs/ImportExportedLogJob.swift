import Fluent
import Foundation
import Queues
import Vapor

struct ImportExportedLogJob: AsyncJob {
  struct Payload: Content {
    let ops: [String]
    let historyId: UUID
  }

  private let jsonDecoder: ContentDecoder

  init() throws {
    self.jsonDecoder = try ContentConfiguration.global.requireDecoder(for: .json)
  }

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    let app = context.application
    if payload.ops.isEmpty {
      throw "Empty export"
    }
    let ops = try self.jsonDecoder.decode(
      [ExportedOperation].self, from: .init(string: "[\(payload.ops.joined(separator: ","))]"),
      headers: [:])
    try await app.db.transaction { transaction in
      if ops.count == 1 {
        _ = try await self.insert(ops: ops[0], on: transaction)
        return
      }
      try await self.treeInsert(ops: ops, on: transaction)
    }
  }

  private func treeInsert(ops operations: [ExportedOperation], on database: Database) async throws {
    for tree in try treeSort(operations) {
      var prevOp: Operation?
      for exportedOp in tree {
        prevOp = try await self.insert(ops: exportedOp, prev: prevOp, on: database)
      }
    }
  }

  private func insert(
    ops exportedOp: ExportedOperation, prev: Operation? = nil, on database: Database
  ) async throws -> Operation {
    if let operation = try await Operation.find(
      .init(cid: exportedOp.cid, did: exportedOp.did), on: database)
    {
      return operation
    }
    let operation = try await exportedOp.normalize(on: database)
    try await operation.create(on: database)
    return operation
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    if let err = error as? OpParseError {
      let exportedOp = try self.jsonDecoder.decode(
        ExportedOperation.self, from: .init(string: payload.ops.first!), headers: [:])
      let reason: BanReason =
        switch err {
        case .invalidHandle:
          .invalidHandle
        case .unknownPreviousOp:
          .missingHistory
        default:
          .incompatibleAtproto
        }
      if let did = try? await Did.find(exportedOp.did, on: app.db) {
        did.banned = true
        did.reason = reason
        try? await did.update(on: app.db)
      } else {
        try? await Did(exportedOp.did, banned: true, reason: reason).create(on: app.db)
      }
    }
    app.logger.report(error: error)
  }
}
