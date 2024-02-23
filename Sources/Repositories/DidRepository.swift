import Vapor

struct DidRepository {
  static let cacheKey = "count:did:plc"

  let req: Request

  func count() async throws -> Int {
    if let cachedCount = try? await self.req.cache.get(Self.cacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Did.query(on: req.db).count()
    do {
      try await self.req.cache.set(Self.cacheKey, to: count, expiresIn: .minutes(5))
    } catch {
      self.req.logger.report(error: error)
    }
    return count
  }
}

extension Request {
  var didRepository: DidRepository {
    .init(req: self)
  }
}
