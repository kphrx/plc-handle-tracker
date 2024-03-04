import Fluent
import Redis

struct HandleMiddleware: AsyncModelMiddleware {
  typealias Model = Handle

  let redis: RedisClient
  let logger: Logger

  func create(model: Model, on db: Database, next: AnyAsyncModelResponder) async throws {
    try await next.create(model, on: db)
    let countCacheKey = RedisKey(HandleRepository.countCacheKey)
    do {
      if try await self.redis.exists(countCacheKey) > 0 {
        _ = try await self.redis.increment(countCacheKey)
      }
      _ = try await self.redis.srem(model.handle, from: RedisKey(HandleRepository.notFoundCacheKey))
    } catch {
      self.logger.report(error: error)
    }
  }
}
