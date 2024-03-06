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
      if try await self.redis.sismember(handleName, of: cacheKey) {
        return false
      }
    } catch {
      self.logger.report(error: error)
    }
    if try await Handle.findBy(handleName: handleName, on: self.db) != nil {
      return true
    }
    do {
      _ = try await self.redis.sadd(handleName, to: cacheKey)
    } catch {
      self.logger.report(error: error)
    }
    return false
  }

  func search(prefix handlePrefix: String) async throws -> [String]? {
    if !Handle.validate(handlePrefix) {
      return nil
    }
    let cacheKey = RedisKey("\(Self.searchCacheKey):\(handlePrefix)")
    do {
      if try await self.redis.exists(cacheKey) > 0 {
        return try await self.redis.zrange(from: cacheKey, fromIndex: 0, as: String.self)
          .compactMap { if let h = $0, h != "." { h } else { nil } }
      }
    } catch {
      self.logger.report(error: error)
    }
    let query =
      if !Environment.getBool("DISABLE_NON_C_LOCALE_POSTGRES_SEARCH_OPTIMIZE")
        && self.db is PostgresDatabase
      {
        Handle.query(on: self.db).filter(\.$handle >= handlePrefix).filter(
          \.$handle
            <= .custom(
              SQLFunction("CONCAT", args: SQLLiteral.string(handlePrefix), SQLLiteral.string("~")))
        )
      } else {
        Handle.query(on: self.db).filter(\.$handle =~ handlePrefix)
      }
    let handles = try await query.all().map { $0.handle }
    do {
      if handles.count > 0 {
        _ = try await self.redis.zadd(handles, to: cacheKey)
      } else {
        _ = try await self.redis.zadd(".", to: cacheKey)
      }
      _ = try await self.redis.expire(cacheKey, after: .minutes(30))
      _ = try await self.redis.sadd(handlePrefix, to: RedisKey(Self.searchCacheKey))
    } catch {
      self.logger.report(error: error)
    }
    return handles
  }

  func createIfNoxExists(_ handleName: String) async throws -> Handle {
    if let handle = try await Handle.findBy(handleName: handleName, on: self.db) {
      return handle
    }
    let handle = try Handle(handleName)
    do {
      try await handle.create(on: self.db)
      return handle
    } catch let error as PostgresError where error.code == .uniqueViolation {
      return try await Handle.findBy(handleName: handleName, on: self.db)!
    }
  }

  func findWithOperations(handleName: String) async throws -> Handle? {
    let cacheKey = RedisKey(Self.notFoundCacheKey)
    do {
      if try await self.redis.sismember(handleName, of: cacheKey) {
        return nil
      }
    } catch {
      self.logger.report(error: error)
    }
    if let handle = try await Handle.findBy(handleName: handleName, withOp: true, on: self.db) {
      return handle
    }
    do {
      _ = try await self.redis.sadd(handleName, to: cacheKey)
    } catch {
      self.logger.report(error: error)
    }
    return nil
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
