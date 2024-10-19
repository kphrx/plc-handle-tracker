import RediStack
import Vapor

struct CleanupCacheCommand: AsyncCommand {
  struct Signature: CommandSignature {}

  var help: String {
    "Cleanup redis caches"
  }

  func run(using context: CommandContext, signature: Signature) async throws {
    let app = context.application
    context.console.print("Clear count")
    _ = try await (
      app.cache.delete(DidRepository.countCacheKey),
      app.cache.delete(HandleRepository.countCacheKey)
    )
    context.console.print("Build count cache")
    let (didCount, handleCount) = try await (
      app.didRepository.count(), app.handleRepository.count()
    )
    context.console.print("Count cache: did:\(didCount), handle:\(handleCount)")
    context.console.print("Clear exists check cache")
    _ = try await (
      app.cache.delete(DidRepository.notFoundCacheKey),
      app.cache.delete(HandleRepository.notFoundCacheKey)
    )
    context.console.print("Clear expired search cache")
    let searchCacheKey = RedisKey(HandleRepository.searchCacheKey)
    let searched = try await app.redis.smembers(of: searchCacheKey, as: String.self)
      .compactMap { value in
        if let value {
          (value, "\(HandleRepository.searchCacheKey):\(value)")
        } else {
          nil
        }
      }
    for (key, cacheKey) in searched {
      if try await app.redis.exists(.init(cacheKey)) > 0 {
        try await app.cache.delete(cacheKey)
        _ = try await app.redis.srem(key, from: searchCacheKey)
      }
    }
  }
}
