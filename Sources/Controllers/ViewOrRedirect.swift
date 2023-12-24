import Vapor

enum ViewOrRedirect: AsyncResponseEncodable {
  case view(_: View, status: HTTPResponseStatus = .ok)
  case redirect(to: String)

  public func encodeResponse(for req: Request) async throws -> Response {
    switch self {
    case .view(let view, let status): try await view.encodeResponse(status: status, for: req)
    case .redirect(let to): req.redirect(to: to)
    }
  }
}
