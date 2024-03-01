import Fluent
import Vapor

struct DidRepository {
  static let countCacheKey = "count:did:plc"
  static let searchCacheKeyPrefix = "search:did:plc"

  let logger: Logger
  let cache: Cache
  let db: Database

  init(app: Application) {
    self.logger = app.logger
    self.cache = app.cache
    self.db = app.db
  }

  init(req: Request) {
    self.logger = req.logger
    self.cache = req.cache
    self.db = req.db
  }

  func count() async throws -> Int {
    if let cachedCount = try? await self.cache.get(Self.countCacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Did.query(on: self.db).count()
    do {
      try await self.cache.set(Self.countCacheKey, to: count, expiresIn: .minutes(5))
    } catch {
      self.logger.report(error: error)
    }
    return count
  }

  func search(did: String) async throws -> Bool {
    let cacheKey = "\(Self.searchCacheKeyPrefix):\(String(did.trimmingPrefix("did:plc:")))"
    if let cachedResult = try? await self.cache.get(cacheKey, as: Bool.self) {
      return cachedResult
    }
    let existsDid = try await Did.find(did, on: self.db) != nil
    do {
      try await self.cache.set(
        cacheKey, to: existsDid, expiresIn: existsDid ? nil : .minutes(10))
    } catch {
      self.logger.report(error: error)
    }
    return existsDid
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
