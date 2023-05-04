import Vapor

enum ViewOrRedirect: AsyncResponseEncodable {
  case view(View)
  case redirect(to: String)

  public func encodeResponse(for req: Request) async throws -> Response {
    switch self {
    case .view(let view): return try await view.encodeResponse(for: req)
    case .redirect(let to): return req.redirect(to: to)
    }
  }
}
