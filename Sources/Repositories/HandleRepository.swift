import Vapor

struct HandleRepository {
  static let cacheKey = "count:handle"

  private(set) var req: Request

  func count() async throws -> Int {
    if let cachedCount = try? await self.req.cache.get(Self.cacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Handle.query(on: req.db).count()
    do {
      try await self.req.cache.set(Self.cacheKey, to: count, expiresIn: .minutes(5))
    } catch {
      self.req.logger.report(error: error)
    }
    return count
  }
}

extension Request {
  var handleRepository: HandleRepository {
    .init(req: self)
  }
}
