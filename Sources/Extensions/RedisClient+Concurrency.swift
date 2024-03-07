import NIOCore
import RediStack

extension RedisClient {
  func increment(_ key: RedisKey) async throws -> Int {
    try await self.increment(key).get()
  }

  func exists(_ keys: [RedisKey]) async throws -> Int {
    try await self.exists(keys).get()
  }

  func exists(_ keys: RedisKey...) async throws -> Int {
    try await self.exists(keys)
  }

  func expire(_ key: RedisKey, after timeout: TimeAmount) async throws -> Bool {
    try await self.expire(key, after: timeout).get()
  }

  func sadd<Value: RESPValueConvertible>(_ elements: [Value], to key: RedisKey) async throws -> Int
  {
    try await self.sadd(elements, to: key).get()
  }

  func sadd<Value: RESPValueConvertible>(_ elements: Value..., to key: RedisKey) async throws -> Int
  {
    try await self.sadd(elements, to: key)
  }

  func sismember<Value: RESPValueConvertible>(_ element: Value, of key: RedisKey) async throws
    -> Bool
  {
    try await self.sismember(element, of: key).get()
  }

  func smembers<Value: RESPValueConvertible>(of key: RedisKey, as type: Value.Type) async throws
    -> [Value?]
  {
    try await self.smembers(of: key, as: type).get()
  }

  func srem<Value: RESPValueConvertible>(_ elements: [Value], from key: RedisKey) async throws
    -> Int
  {
    try await self.srem(elements, from: key).get()
  }

  func srem<Value: RESPValueConvertible>(_ elements: Value..., from key: RedisKey) async throws
    -> Int
  {
    try await self.srem(elements, from: key)
  }

  func zadd<Value: RESPValueConvertible>(
    _ elements: [(element: Value, score: Double)], to key: RedisKey
  ) async throws -> Int {
    try await self.zadd(elements, to: key).get()
  }

  func zadd<Value: RESPValueConvertible>(
    _ elements: (element: Value, score: Double)..., to key: RedisKey
  ) async throws -> Int {
    try await self.zadd(elements, to: key)
  }

  func zadd<Value: RESPValueConvertible>(
    _ elements: [Value], defaultRank rank: Double = 0, to key: RedisKey
  ) async throws -> Int {
    try await self.zadd(elements.map { ($0, rank) }, to: key).get()
  }

  func zadd<Value: RESPValueConvertible>(
    _ elements: Value..., defaultRank rank: Double = 0, to key: RedisKey
  ) async throws -> Int {
    try await self.zadd(elements, defaultRank: rank, to: key)
  }

  func zrange(from key: RedisKey, fromIndex index: Int) async throws -> [RESPValue] {
    try await self.zrange(from: key, fromIndex: index).get()
  }

  func zrange<Value: RESPValueConvertible>(
    from key: RedisKey, fromIndex index: Int, as type: Value.Type
  ) async throws -> [Value?] {
    try await self.zrange(from: key, fromIndex: index).map(type.init(fromRESP:))
  }
}
