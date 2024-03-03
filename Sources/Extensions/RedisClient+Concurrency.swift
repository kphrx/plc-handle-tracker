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

  func lpos<Value: RESPValueConvertible>(
    _ element: Value, in key: RedisKey, rank: Int? = nil, maxlen: Int? = nil
  ) async throws -> Int? {
    try await self.lpos(element, in: key, rank: rank, maxlen: maxlen).get()
  }

  func lpos<Value: RESPValueConvertible>(
    _ element: Value, in key: RedisKey, rank: Int? = nil, count: Int, maxlen: Int? = nil
  ) async throws -> [Int?] {
    try await self.lpos(element, in: key, rank: rank, count: count, maxlen: maxlen).get()
  }
}
