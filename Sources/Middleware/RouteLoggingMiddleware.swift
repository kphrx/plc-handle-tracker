import Vapor

class RouteLoggingMiddleware: AsyncMiddleware {
  let logLevel: Logger.Level = .info

  func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
    let query =
      if let query = request.url.query {
        "?\(query.removingPercentEncoding ?? query)"
      } else {
        ""
      }
    request.logger.log(
      level: self.logLevel,
      "\(request.method) \(request.url.path.removingPercentEncoding ?? request.url.path)\(query)")
    return try await next.respond(to: request)
  }
}
