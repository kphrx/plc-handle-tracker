import Fluent
import FluentPostgresDriver
import Queues
import Redis
import Vapor

struct DidRepository {
  static let countCacheKey = "count:did:plc"
  static let notFoundCacheKey = "not-found:did:plc"

  let logger: Logger
  let queue: Queue
  let cache: Cache
  let redis: RedisClient
  let db: Database

  init(app: Application) {
    self.logger = app.logger
    self.queue = app.queues.queue
    self.cache = app.cache
    self.redis = app.redis
    self.db = app.db
  }

  init(req: Request) {
    self.logger = req.logger
    self.queue = req.queue
    self.cache = req.cache
    self.redis = req.redis
    self.db = req.db
  }

  func count() async throws -> Int {
    if let cachedCount = try? await self.cache.get(Self.countCacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Did.query(on: self.db).count()
    do {
      try await self.cache.set(Self.countCacheKey, to: count)
    } catch {
      self.logger.report(error: error)
    }
    return count
  }

  func search(did: String) async throws -> Bool {
    let didSpecificId = String(did.trimmingPrefix("did:plc:"))
    let cacheKey = RedisKey(Self.notFoundCacheKey)
    do {
      if try await self.redis.sismember(didSpecificId, of: cacheKey) {
        return false
      }
    } catch {
      self.logger.report(error: error)
    }
    if try await Did.find(did, on: self.db) != nil {
      return true
    }
    do {
      _ = try await self.redis.sadd(didSpecificId, to: cacheKey)
    } catch {
      self.logger.report(error: error)
    }
    return false
  }

  func ban(_ dids: String..., reason: BanReason = .incompatibleAtproto) async throws {
    try await self.ban(dids: dids, reason: reason)
  }

  func ban(dids: [String], reason: BanReason = .incompatibleAtproto) async throws {
    for did in dids {
      guard let did = try await Did.find(did, on: self.db) else {
        try await Did(did, banned: true, reason: reason).create(on: self.db)
        return
      }
      did.banned = true
      did.reason = reason
      try await did.update(on: self.db)
    }
  }

  func unban(_ did: String) async throws {
    guard let did = try await Did.find(did, on: self.db) else {
      try await Did(did).create(on: self.db)
      return
    }
    did.banned = false
    did.reason = nil
    try await did.update(on: self.db)
  }

  func createIfNoxExists(_ did: String) async throws {
    if !Did.validate(did: did) {
      throw "Invalid DID Placeholder"
    }
    if try await Did.find(did, on: self.db) != nil {
      return
    }
    do {
      try await Did(did).create(on: self.db)
    } catch let error as PostgresError where error.code == .uniqueViolation {
      return
    }
  }

  func findOrFetch(_ did: String) async throws -> Did? {
    let cacheKey = RedisKey(Self.notFoundCacheKey)
    let didSpecificId = String(did.trimmingPrefix("did:plc:"))
    do {
      if try await self.redis.sismember(didSpecificId, of: cacheKey) {
        await self.dispatchFetchJob(did)
        return nil
      }
    } catch {
      self.logger.report(error: error)
    }
    if let didPlc = try await Did.findWithOperations(did, on: self.db) {
      return didPlc
    }
    do {
      _ = try await self.redis.sadd(didSpecificId, to: cacheKey)
    } catch {
      self.logger.report(error: error)
    }
    await self.dispatchFetchJob(did)
    return nil
  }

  private func dispatchFetchJob(_ did: String) async {
    let cacheKey = "last-fetch:\(did)"
    do {
      if let lastFetch = try await self.cache.get(cacheKey, as: Date.self) {
        self.logger.debug("\(did) already fetch in \(lastFetch)")
        return
      }
      try await self.queue.dispatch(FetchDidJob.self, did)
      try await self.cache.set(cacheKey, to: Date(), expiresIn: .days(1))
    } catch {
      self.logger.report(error: error)
    }
  }
}

extension DidRepository {
  func ban(_ dids: String, error err: OpParseError) async throws {
    let reason: BanReason =
      switch err {
        case .invalidHandle:
          .invalidHandle
        case .unknownPreviousOp:
          .missingHistory
        default:
          .incompatibleAtproto
      }
    try await self.ban(dids, reason: reason)
  }
}

extension Application {
  var didRepository: DidRepository {
    .init(app: self)
  }
}

extension Request {
  var didRepository: DidRepository {
    .init(req: self)
  }
}
