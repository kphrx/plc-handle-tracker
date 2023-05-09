import Vapor

struct ErrorContext: Content {
  let title: String
  let reason: String?
}

struct ErrorMiddleware: AsyncMiddleware {
  let environment: Environment

  func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
    do {
      return try await next.respond(to: req)
    } catch {
      let abort = error
      do {
        return try await self.handle(error: abort, for: req)
      } catch {
        throw abort
      }
    }
  }

  private func handle(error: Error, for req: Request) async throws -> Response {
    let status: HTTPStatus
    let reason: String?
    switch error {
    case let abort as AbortError:
      status = abort.status
      reason = abort.reason != status.reasonPhrase ? abort.reason : nil
    default:
      status = .internalServerError
      reason = self.environment.isRelease ? "Something went wrong." : String(describing: error)
    }
    let context = ErrorContext(title: "\(status.code) \(status.reasonPhrase)", reason: reason)
    let res: Response
    do {
      res = try await req.view.render("error/\(status.code)", context).encodeResponse(for: req)
    } catch {
      res = try await req.view.render("error/default", context).encodeResponse(for: req)
    }
    res.status = status
    req.logger.report(error: error)
    return res
  }
}
