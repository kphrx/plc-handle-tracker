import Fluent
import Foundation
import Queues
import Vapor

struct ImportAuditableLogJob: AsyncJob {
  typealias Payload = String

  func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
    if !Did.validate(did: payload) {
      throw "Invalid DID Placeholder"
    }
    let app = context.application
    let response = try await app.client.get("https://plc.directory/\(payload)/log/audit")
    let ops = try response.content.decode([ExportedOperation].self)
    try await app.db.transaction { transaction in
      try await self.insert(ops: ops, on: transaction)
    }
    do {
      try await app.didRepository.unban(payload)
    } catch {
      app.logger.report(error: error)
    }
    do {
      try await PollingJobStatus.query(on: app.db).set(\.$status, to: .success).filter(
        \.$did == payload
      ).update()
    } catch {
      app.logger.report(error: error)
    }
  }

  private func insert(ops operations: [ExportedOperation], on database: Database) async throws {
    var prevOp: Operation?
    for exportedOp in operations {
      if let operation = try await Operation.find(
        .init(cid: exportedOp.cid, did: exportedOp.did), on: database)
      {
        prevOp = operation
        continue
      }
      let operation = try await Operation(exportedOp: exportedOp, prevOp: prevOp, on: database)
      try await operation.create(on: database)
      prevOp = operation
    }
  }

  func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
    let app = context.application
    app.logger.report(error: error)
    guard let err = error as? OpParseError else {
      return
    }
    do {
      try await app.didRepository.ban(payload, error: err)
    } catch {
      app.logger.report(error: error)
    }
    do {
      try await PollingJobStatus.query(on: app.db).set(\.$status, to: .banned).filter(
        \.$status != .banned
      ).filter(\.$did == payload).update()
    } catch {
      app.logger.report(error: error)
    }
  }
}
