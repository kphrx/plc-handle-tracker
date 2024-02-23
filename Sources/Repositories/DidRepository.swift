import Vapor

struct DidRepository {
  static let countCacheKey = "count:did:plc"
  static let searchCacheKeyPrefix = "search:did:plc"

  let req: Request

  func count() async throws -> Int {
    if let cachedCount = try? await self.req.cache.get(Self.countCacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Did.query(on: req.db).count()
    do {
      try await self.req.cache.set(Self.countCacheKey, to: count, expiresIn: .minutes(5))
    } catch {
      self.req.logger.report(error: error)
    }
    return count
  }

  func search(did: String) async throws -> Bool {
    let cacheKey = "\(Self.searchCacheKeyPrefix):\(String(did.trimmingPrefix("did:plc:")))"
    if let cachedResult = try? await self.req.cache.get(cacheKey, as: Bool.self) {
      return cachedResult
    }
    let existsDid = try await Did.find(did, on: self.req.db) != nil
    do {
      try await self.req.cache.set(
        cacheKey, to: existsDid, expiresIn: existsDid ? nil : .minutes(10))
    } catch {
      self.req.logger.report(error: error)
    }
    return existsDid
  }
}

extension Request {
  var didRepository: DidRepository {
    .init(req: self)
  }
}
