import Vapor

struct ImportAuditableLogCommand: AsyncCommand {
  struct Signature: CommandSignature {
    @Argument(name: "did")
    var did: String
  }

  var help: String {
    "Import from https://plc.directory/:did/log/audit"
  }

  func run(using context: CommandContext, signature: Signature) async throws {
    try await context.application.queues.queue.dispatch(ImportAuditableLogJob.self, signature.did)
    context.console.print("Queued fetching auditable log for \(signature.did)")
  }
}
