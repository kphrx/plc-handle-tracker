import Fluent
import FluentPostgresDriver
import Redis
import Vapor

struct HandleRepository {
  static let countCacheKey = "count:handle"
  static let existsCacheKey = "exists:handle"
  static let searchCacheKey = "search:handle"

  let req: Request

  func count() async throws -> Int {
    if let cachedCount = try? await self.req.cache.get(Self.countCacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Handle.query(on: self.req.db).count()
    do {
      try await self.req.cache.set(Self.countCacheKey, to: count, expiresIn: .minutes(5))
    } catch {
      self.req.logger.report(error: error)
    }
    return count
  }

  func search(prefix handle: String) async throws -> (Bool, [Handle]?) {
    if handle.count <= 3 {
      return (false, nil)
    }
    if try await self.exists(handle: handle) {
      return (true, nil)
    }
    return (false, try await self.getHandles(handle: handle))
  }

  private func exists(handle: String) async throws -> Bool {
    let cacheKey = "\(Self.existsCacheKey):\(handle)"
    if let cachedResult = try? await self.req.cache.get(cacheKey, as: Bool.self) {
      return cachedResult
    }
    let existsHandle =
      try await Handle.query(on: self.req.db).filter(\.$handle == handle).first() != nil
    do {
      if existsHandle {
        try await self.req.cache.set(cacheKey, to: existsHandle)
        _ = try await self.req.redis.lpush(cacheKey, into: RedisKey(Self.existsCacheKey))
      } else {
        try await self.req.cache.set(cacheKey, to: existsHandle, expiresIn: .minutes(10))
      }
    } catch {
      self.req.logger.report(error: error)
    }
    return existsHandle
  }

  private func getHandles(handle: String) async throws -> [Handle] {
    let cacheKey = "\(Self.searchCacheKey):\(handle)"
    if let cachedResult = try? await self.req.cache.get(cacheKey, as: [Handle].self) {
      return cachedResult
    }
    let handles =
      if !Environment.getBool("DISABLE_NON_C_LOCALE_POSTGRES_SEARCH_OPTIMIZE")
        && self.req.db is PostgresDatabase
      {
        try await Handle.query(on: self.req.db).filter(\.$handle >= handle).filter(
          \.$handle
            <= .custom(
              SQLFunction("CONCAT", args: SQLLiteral.string(handle), SQLLiteral.string("~")))
        ).all()
      } else {
        try await Handle.query(on: self.req.db).filter(\.$handle =~ handle).all()
      }
    do {
      try await self.req.cache.set(cacheKey, to: handles, expiresIn: .minutes(30))
      _ = try await self.req.redis.lpush(handle, into: RedisKey(Self.searchCacheKey))
    } catch {
      self.req.logger.report(error: error)
    }
    return handles
  }
}

extension Request {
  var handleRepository: HandleRepository {
    .init(req: self)
  }
}
