import Fluent
import FluentPostgresDriver
import Redis
import Vapor

struct HandleRepository {
  static let countCacheKey = "count:handle"
  static let notFoundCacheKey = "not-found:handle"
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

  func exists(_ handleName: String) async throws -> Bool {
    if !Handle.validate(handleName) {
      return false
    }
    let cacheKey = RedisKey(Self.notFoundCacheKey)
    do {
      if try await self.redis.lpos(handleName, in: cacheKey) != nil {
        return false
      }
    } catch {
      self.logger.report(error: error)
    }
    if try await Handle.query(on: self.db).filter(\.$handle == handleName).first() != nil {
      return true
    }
    do {
      _ = try await self.redis.lpush(handleName, into: cacheKey)
    } catch {
      self.logger.report(error: error)
    }
    return false
  }

  func search(prefix handlePrefix: String) async throws -> [Handle]? {
    if !Handle.validate(handlePrefix) {
      return nil
    }
    let cacheKey = RedisKey("\(Self.searchCacheKey):\(handlePrefix)")
    do {
      if try await self.redis.exists(cacheKey) > 0 {
        return try await self.redis.lrange(from: cacheKey, fromIndex: 0, asJSON: Handle.self)
          .compactMap { $0 }
      }
    } catch {
      self.logger.report(error: error)
    }
    let handles =
      if !Environment.getBool("DISABLE_NON_C_LOCALE_POSTGRES_SEARCH_OPTIMIZE")
        && self.db is PostgresDatabase
      {
        try await Handle.query(on: self.db).filter(\.$handle >= handlePrefix).filter(
          \.$handle
            <= .custom(
              SQLFunction("CONCAT", args: SQLLiteral.string(handlePrefix), SQLLiteral.string("~")))
        ).all()
      } else {
        try await Handle.query(on: self.db).filter(\.$handle =~ handlePrefix).all()
      }
    do {
      _ = try await self.redis.lpush(jsonElements: handles, into: cacheKey)
      _ = try await self.redis.expire(cacheKey, after: .minutes(30))
      _ = try await self.redis.lpush(handlePrefix, into: RedisKey(Self.searchCacheKey))
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
