import Vapor

class RouteLoggingMiddleware: Middleware {
  let logLevel: Logger.Level = .info

  func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
    let query =
      if let query = request.url.query {
        "?\(query.removingPercentEncoding ?? query)"
      } else {
        ""
      }
    request.logger.log(
      level: self.logLevel,
      "\(request.method) \(request.url.path.removingPercentEncoding ?? request.url.path)\(query)")
    return next.respond(to: request)
  }
}
