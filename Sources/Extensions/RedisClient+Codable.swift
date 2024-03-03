import Foundation
import NIOCore
import RediStack

extension RedisClient {
  func lpush<Value: Encodable>(jsonElements elements: [Value], into key: RedisKey)
    -> EventLoopFuture<Int>
  {
    do {
      return try self.lpush(elements.map(JSONEncoder().encode(_:)), into: key)
    } catch {
      return self.eventLoop.makeFailedFuture(error)
    }
  }

  func lpush<Value: Encodable>(jsonElements elements: Value..., into key: RedisKey)
    -> EventLoopFuture<Int>
  {
    self.lpush(jsonElements: elements, into: key)
  }

  func lrange<Value: Decodable>(from key: RedisKey, fromIndex index: Int, asJSON type: Value.Type)
    -> EventLoopFuture<[Value?]>
  {
    self.lrange(from: key, fromIndex: index, as: Data.self).flatMapThrowing {
      try $0.map { data in
        if let data {
          try JSONDecoder().decode(type, from: data)
        } else {
          nil
        }
      }
    }
  }
}
