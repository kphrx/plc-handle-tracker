import Fluent
import FluentPostgresDriver
import Vapor

struct HandleRepository {
  static let cacheKey = "count:handle"

  let req: Request

  func count() async throws -> Int {
    if let cachedCount = try? await self.req.cache.get(Self.cacheKey, as: Int.self) {
      return cachedCount
    }
    let count = try await Handle.query(on: self.req.db).count()
    do {
      try await self.req.cache.set(Self.cacheKey, to: count, expiresIn: .minutes(5))
    } catch {
      self.req.logger.report(error: error)
    }
    return count
  }

  func search(prefix handle: String) async throws -> (Bool, [Handle]?) {
    if handle.count <= 3 {
      return (false, nil)
    }
    if try await Handle.query(on: self.req.db).filter(\.$handle == handle).first() != nil {
      return (true, nil)
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
    return (false, handles)
  }
}

extension Request {
  var handleRepository: HandleRepository {
    .init(req: self)
  }
}
