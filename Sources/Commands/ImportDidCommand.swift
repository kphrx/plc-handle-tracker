import Vapor

struct ImportDidCommand: AsyncCommand {
  struct Signature: CommandSignature {
    @Argument(name: "did")
    var did: String
  }

  var help: String {
    "Import from https://plc.directory/:did/log/audit"
  }

  func run(using context: CommandContext, signature: Signature) async throws {
    if !validateDidPlaceholder(signature.did) {
      throw "Invalid DID Placeholder"
    }
    let app = context.application
    let res = try await app.client.send(.HEAD, to: "https://plc.directory/\(signature.did)")
    if 299 >= res.status.code {
      try await app.queues.queue.dispatch(ImportAuditableLogJob.self, signature.did)
      context.console.print("Queued fetching auditable log: \(signature.did)")
    } else {
      context.console.print("Not found DID: \(signature.did), resCode: \(res.status.code)")
    }
  }
}
