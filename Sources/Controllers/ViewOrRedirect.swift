import Vapor

enum ViewOrRedirect: AsyncResponseEncodable {
  case view(_: View, status: HTTPResponseStatus = .ok)
  case redirect(to: String)

  public func encodeResponse(for req: Request) async throws -> Response {
    switch self {
    case .view(let view, let status):
      let res = try await view.encodeResponse(for: req)
      res.status = status
      return res
    case .redirect(let to): return req.redirect(to: to)
    }
  }
}
