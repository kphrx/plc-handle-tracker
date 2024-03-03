import Fluent
import Redis

struct DidMiddleware: AsyncModelMiddleware {
  typealias Model = Did

  let redis: RedisClient
  let logger: Logger

  func create(model: Model, on db: Database, next: AnyAsyncModelResponder) async throws {
    try await next.create(model, on: db)
    let countCacheKey = RedisKey(DidRepository.countCacheKey)
    do {
      if try await self.redis.exists(countCacheKey) > 0 {
        _ = try await self.redis.increment(countCacheKey)
      }
    } catch {
      self.logger.report(error: error)
    }
  }
}
