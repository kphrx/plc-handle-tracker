import Fluent
import Redis
import Vapor

struct DidMiddleware: AsyncModelMiddleware {
  typealias Model = Did

  let app: Application

  var redis: RedisClient {
    self.app.redis
  }

  var logger: Logger {
    self.app.logger
  }

  func create(model: Model, on db: Database, next: AnyAsyncModelResponder) async throws {
    try await next.create(model, on: db)
    let countCacheKey = RedisKey(DidRepository.countCacheKey)
    do {
      if try await self.redis.exists(countCacheKey) > 0 {
        _ = try await self.redis.increment(countCacheKey)
      }
      _ = try await self.redis.srem(
        String(model.requireID().trimmingPrefix("did:plc:")),
        from: RedisKey(DidRepository.notFoundCacheKey))
    } catch {
      self.logger.report(error: error)
    }
  }
}
