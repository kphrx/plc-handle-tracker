import Fluent
import Redis

struct DidMiddleware: AsyncModelMiddleware {
  typealias Model = Did

  let redis: RedisClient
  let logger: Logger

  func create(model: Model, on db: Database, next: AnyAsyncModelResponder) async throws {
    try await next.create(model, on: db)
    do {
      if try await self.redis.exists(key: RedisKey(DidRepository.countCacheKey)) != 0 {
        _ = try await self.redis.increment(RedisKey(DidRepository.countCacheKey))
      }
    } catch {
      self.logger.report(error: error)
    }
  }
}
