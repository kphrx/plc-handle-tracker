import Redis

extension RedisClient {
  func lpush<Value: RESPValueConvertible>(_ elements: [Value], into: RedisKey) async throws -> Int {
    try await self.lpush(elements, into: into).get()
  }

  func lpush<Value: RESPValueConvertible>(_ elements: Value..., into: RedisKey) async throws -> Int
  {
    try await self.lpush(elements, into: into)
  }

  func increment(_ key: RedisKey) async throws -> Int {
    try await self.increment(key).get()
  }

  func exists(key: RedisKey) async throws -> Int {
    try await self.exists(key).get()
  }
}
