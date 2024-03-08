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
    try await ops.insert(app: app)
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
