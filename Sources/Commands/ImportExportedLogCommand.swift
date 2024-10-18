import Vapor

struct ImportExportedLogCommand: AsyncCommand {
  struct Signature: CommandSignature {
    @Option(name: "count", short: nil)
    var count: UInt?
  }

  var help: String {
    "Import from https://plc.directory/export"
  }

  func run(using context: CommandContext, signature: Signature) async throws {
    let app = context.application
    let after = try await PollingPlcServerExportJob.lastPolledDateWithoutFailure(on: app.db)
    let history = PollingHistory()
    try await history.create(on: app.db)
    try await app.queues.queue(.polling)
      .dispatch(
        PollingPlcServerExportJob.self,
        .init(after: after, count: signature.count ?? 1000, history: history))
    if let after {
      context.console.print("Queued fetching export log, after \(after)")
    } else {
      context.console.print("Queued fetching export log")
    }
  }
}
