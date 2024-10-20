import Vapor

struct ErrorContext: BaseContext {
  let title: String?
  let route: String
  let reason: String?
}

struct ErrorMiddleware: AsyncMiddleware {
  let environment: Environment

  func respond(to req: Request, chainingTo next: AsyncResponder) async -> Response {
    do {
      return try await next.respond(to: req)
    } catch {
      req.logger.report(error: error)
      let (status, reason) = self.handle(error: error)
      let context = ErrorContext(
        title: "\(status.code) \(status.reasonPhrase)", route: req.route?.description ?? "",
        reason: reason)
      return await self.response(status: status, context: context, reason: reason, for: req)
    }
  }

  private func handle(error abort: AbortError) -> (HTTPStatus, String?) {
    if abort.reason != abort.status.reasonPhrase {
      (abort.status, abort.reason)
    } else {
      (abort.status, nil)
    }
  }

  private func handle(error: Error) -> (HTTPStatus, String?) {
    if self.environment.isRelease {
      (.internalServerError, "Something went wrong.")
    } else {
      (.internalServerError, String(describing: error))
    }
  }

  private func response(
    status: HTTPStatus, context: ErrorContext, reason: String?, for req: Request
  ) async -> Response {
    do {
      return try await self.render(status: status, context: context, for: req)
    } catch {
      return .init(
        status: status,
        headers: [HTTPHeaders.Name.contentType.description: "text/plain; charset=utf-8"],
        body: .init(
          string: "Oops: \(reason ?? "Something went wrong.")",
          byteBufferAllocator: req.byteBufferAllocator))
    }
  }

  private func render(status: HTTPStatus, context: ErrorContext, for req: Request) async throws
    -> Response
  {
    do {
      return try await req.view.render("error/\(status.code)", context)
        .encodeResponse(status: status, for: req)
    } catch {
      return try await req.view.render("error/default", context)
        .encodeResponse(status: status, for: req)
    }
  }
}
