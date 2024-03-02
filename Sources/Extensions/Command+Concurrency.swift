import Vapor

protocol AsyncCommand: Command {
  func run(using context: CommandContext, signature: Signature) async throws
}

extension Command where Self: AsyncCommand {
  func run(using context: CommandContext, signature: Signature) throws {
    let promise = context
      .application
      .eventLoopGroup
      .next()
      .makePromise(of: Void.self)
    promise.completeWithTask {
      try await self.run(using: context, signature: signature)
    }
    try promise.futureResult.wait()
  }
}
