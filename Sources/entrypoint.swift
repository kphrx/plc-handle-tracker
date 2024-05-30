import Dispatch
import Logging
import Vapor

/// This extension is temporary and can be removed once Vapor gets this support.
extension Vapor.Application {
  fileprivate static let baseExecutionQueue = DispatchQueue(label: "vapor.codes.entrypoint")

  fileprivate func runFromAsyncMainEntrypoint() async throws {
    try await withCheckedThrowingContinuation { continuation in
      Vapor.Application.baseExecutionQueue.async { [self] in
        do {
          try self.run()
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}

@main
enum Entrypoint {
  static func main() async throws {
    var env = try Environment.detect()
    try LoggingSystem.bootstrap(from: &env)

    let app = try await Application.make(env)
    defer { app.shutdown() }

    try await configure(app)
    do {
      try await app.runFromAsyncMainEntrypoint()
    } catch {
      exit(1)
    }
  }
}
