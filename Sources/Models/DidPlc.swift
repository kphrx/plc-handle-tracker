import Base32
import Fluent
import Vapor

final class DidPlc: Model, @unchecked Sendable {
  static let schema = "did_plcs"

  struct SpecificId: Codable, Hashable, Sendable {
    let raw: Data

    init(raw: Data) throws {
      guard raw.count == 15 else {
        throw FluentError.invalidField(name: "id", valueType: Self.self, error: "Invalid length")
      }
      self.raw = raw
    }
  }

  @ID(custom: .id, generatedBy: .user)
  var id: SpecificId?

  @Field(key: "banned")
  var banned: Bool

  @OptionalEnum(key: "reason")
  var reason: BanReason?

  init() {}

  init(_ id: SpecificId, banned: Bool = false, reason: BanReason? = nil) {
    self.id = id
    self.banned = banned
    if banned {
      self.reason = reason ?? .incompatibleAtproto
    }
  }
}

extension DidPlc.SpecificId {
  var specificId: String {
    Base32.encode(self.raw)
  }

  var didString: String {
    "did:plc:\(self.specificId)"
  }

  init(specificId: String) throws {
    let data = try Base32.decode(specificId)
    try self.init(raw: data)
  }

  init(didString value: String) throws {
    guard value.hasPrefix("did:plc:") else {
      throw FluentError.invalidField(name: "id", valueType: Self.self, error: "Invalid format")
    }
    let specificId = String(value.dropFirst("did:plc:".count))
    try self.init(specificId: specificId)
  }
}
