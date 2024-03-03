import Fluent
import FluentPostgresDriver
import Redis
import Vapor

struct HandleRepository {
  static let countCacheKey = "count:handle"
  static let existsCacheKey = "exists:handle"
  static let searchCacheKey = "search:handle"

  let logger: Logger
  let cache: Cache
  let redis: RedisClient
  let db: Database

  init(app: Application) {
    self.redis = app.redis
    self.logger = app.logger
    self.cache = app.cache
    self.db = app.db
  }

  init(req: Request) {
    self.redis = req.redis
    self.logger = req.logger
    self.cache = req.cache
    self.db = req.db
  }

  func count() async throws -> Int {
    if let cachedCount = try? await self.cache.get(Self.countCacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Handle.query(on: self.db).count()
    do {
      try await self.cache.set(Self.countCacheKey, to: count)
    } catch {
      self.logger.report(error: error)
    }
    return count
  }

  func exists(handle: String) async throws -> Bool {
    if !Handle.validate(handle: handle) {
      return false
    }
    let cacheKey = "\(Self.existsCacheKey):\(handle)"
    if let cachedResult = try? await self.cache.get(cacheKey, as: Bool.self) {
      return cachedResult
    }
    let existsHandle =
      try await Handle.query(on: self.db).filter(\.$handle == handle).first() != nil
    do {
      if existsHandle {
        try await self.cache.set(cacheKey, to: existsHandle)
        _ = try await self.redis.lpush(cacheKey, into: RedisKey(Self.existsCacheKey))
      } else {
        try await self.cache.set(cacheKey, to: existsHandle, expiresIn: .minutes(10))
      }
    } catch {
      self.logger.report(error: error)
    }
    return existsHandle
  }

  func search(prefix handle: String) async throws -> [Handle]? {
    if !Handle.validate(handle: handle) {
      return nil
    }
    let cacheKey = "\(Self.searchCacheKey):\(handle)"
    if let cachedResult = try? await self.cache.get(cacheKey, as: [Handle].self) {
      return cachedResult
    }
    let handles =
      if !Environment.getBool("DISABLE_NON_C_LOCALE_POSTGRES_SEARCH_OPTIMIZE")
        && self.db is PostgresDatabase
      {
        try await Handle.query(on: self.db).filter(\.$handle >= handle).filter(
          \.$handle
            <= .custom(
              SQLFunction("CONCAT", args: SQLLiteral.string(handle), SQLLiteral.string("~")))
        ).all()
      } else {
        try await Handle.query(on: self.db).filter(\.$handle =~ handle).all()
      }
    do {
      try await self.cache.set(cacheKey, to: handles, expiresIn: .minutes(30))
      _ = try await self.redis.lpush(handle, into: RedisKey(Self.searchCacheKey))
    } catch {
      self.logger.report(error: error)
    }
    return handles
  }

  func createIfNoxExists(_ handleName: String) async throws -> Handle {
    if let handle = try await Handle.query(on: self.db).filter(\.$handle == handleName).first() {
      return handle
    }
    let handle = try Handle(handleName)
    do {
      try await handle.create(on: self.db)
      return handle
    } catch let error as PostgresError where error.code == .uniqueViolation {
      return try await Handle.query(on: self.db).filter(\.$handle == handleName).first()!
    }
  }
}

extension Application {
  var handleRepository: HandleRepository {
    .init(app: self)
  }
}

extension Request {
  var handleRepository: HandleRepository {
    .init(req: self)
  }
}
