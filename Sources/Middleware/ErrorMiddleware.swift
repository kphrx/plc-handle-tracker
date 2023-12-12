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
      return await self.handle(error: error, for: req)
    }
  }

  private func handle(error: Error, for req: Request) async -> Response {
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
    let context = ErrorContext(
      title: "\(status.code) \(status.reasonPhrase)", route: req.route?.description ?? "",
      reason: reason)
    let res: Response
    do {
      res = try await self.render(for: req, code: status.code, context: context)
    } catch {
      res = .init(
        body: .init(
          string: "Oops: \(reason ?? "Something went wrong.")",
          byteBufferAllocator: req.byteBufferAllocator))
      res.headers.add(name: .contentType, value: "text/plain; charset=utf-8")
    }
    res.status = status
    req.logger.report(error: error)
    return res
  }

  private func render(for req: Request, code statusCode: UInt, context: ErrorContext) async throws
    -> Response
  {
    do {
      return try await req.view.render("error/\(statusCode)", context).encodeResponse(for: req)
    } catch {
      return try await req.view.render("error/default", context).encodeResponse(for: req)
    }
  }
}
