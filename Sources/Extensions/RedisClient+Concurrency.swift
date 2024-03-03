import NIOCore
import RediStack

extension RedisClient {
  func lpush<Value: RESPValueConvertible>(_ elements: [Value], into: RedisKey) async throws -> Int {
    try await self.lpush(elements, into: into).get()
  }

  func lpush<Value: RESPValueConvertible>(_ elements: Value..., into: RedisKey) async throws -> Int
  {
    try await self.lpush(elements, into: into)
  }

  func lpush<Value: Encodable>(jsonElements elements: [Value], into: RedisKey) async throws -> Int {
    try await self.lpush(jsonElements: elements, into: into).get()
  }

  func lpush<Value: Encodable>(jsonElements elements: Value..., into: RedisKey) async throws -> Int
  {
    try await self.lpush(jsonElements: elements, into: into)
  }

  func increment(_ key: RedisKey) async throws -> Int {
    try await self.increment(key).get()
  }

  func exists(_ keys: [RedisKey]) async throws -> Int {
    try await self.exists(keys).get()
  }

  func exists(_ keys: RedisKey...) async throws -> Int {
    try await self.exists(keys)
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

  func lrange<Value: Decodable>(from key: RedisKey, fromIndex index: Int, asJSON type: Value.Type)
    async throws -> [Value?]
  {
    try await self.lrange(from: key, fromIndex: index, asJSON: type).get()
  }

  func expire(_ key: RedisKey, after timeout: TimeAmount) async throws -> Bool {
    try await self.expire(key, after: timeout).get()
  }
}
