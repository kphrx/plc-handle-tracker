import Redis
import Vapor

extension RedisClient {
  func lpush<Value: RESPValueConvertible>(_ elements: Value..., into: RedisKey) async throws -> Int
  {
    try await self.lpush(elements, into: into).get()
  }
}
