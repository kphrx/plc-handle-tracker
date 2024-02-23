import Vapor

enum ViewOrRedirect: AsyncResponseEncodable {
  case view(_: View, status: HTTPResponseStatus = .ok)
  case redirect(to: String, redirectType: Redirect = .normal)

  public func encodeResponse(for req: Request) async throws -> Response {
    switch self {
    case .view(let view, let status): try await view.encodeResponse(status: status, for: req)
    case .redirect(let to, let redirectType): req.redirect(to: to, redirectType: redirectType)
    }
  }
}
