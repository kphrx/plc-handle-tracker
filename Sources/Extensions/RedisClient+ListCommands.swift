import NIOCore
import RediStack

extension RedisClient {
  func lpos<Value: RESPValueConvertible>(
    _ value: Value, in key: RedisKey, rank: Int? = nil, maxlen: Int? = nil
  ) -> EventLoopFuture<Int?> {
    var args: [RESPValue] = [
      .init(from: key),
      value.convertedToRESPValue(),
    ]
    if let rank {
      args.append(rank.convertedToRESPValue())
    }
    if let maxlen {
      args.append(maxlen.convertedToRESPValue())
    }
    return self.send(command: "LPOS", with: args).map(Int.init(fromRESP:))
  }

  func lpos<Value: RESPValueConvertible>(
    _ value: Value, in key: RedisKey, rank: Int? = nil, count: Int, maxlen: Int? = nil
  ) -> EventLoopFuture<[Int?]> {
    var args: [RESPValue] = [
      .init(from: key),
      value.convertedToRESPValue(),
    ]
    if let rank {
      args.append(rank.convertedToRESPValue())
    }
    args.append(count.convertedToRESPValue())
    if let maxlen {
      args.append(maxlen.convertedToRESPValue())
    }
    return self.send(command: "LPOS", with: args).flatMapThrowing({
      guard let value = [RESPValue].init(fromRESP: $0) else {
        throw RedisClientError.failedRESPConversion(to: [RESPValue].self)
      }
      return value
    }).map { $0.map(Int.init(fromRESP:)) }
  }
}
