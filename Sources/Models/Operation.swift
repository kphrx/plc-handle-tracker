import Fluent
import Vapor

final class Operation: Model, Content {
  static let schema = "operations"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "cid")
  var cid: String

  @Parent(key: "did")
  var did: Did

  @Field(key: "nullified")
  var nullified: Bool

  @Field(key: "created_at")
  var createdAt: Date

  @OptionalParent(key: "prev")
  var prev: Operation?

  @Children(for: \.$prev)
  var nexts: [Operation]

  @Parent(key: "handle")
  var handle: Handle

  @Parent(key: "pds")
  var pds: PersonalDataServer

  init() {}

  init(
    id: UUID? = nil, cid: String, did: Did, nullified: Bool, createdAt: Date,
    prev: Operation? = nil, handle: Handle, pds: PersonalDataServer
  ) throws {
    self.id = id
    self.cid = cid
    self.$did.id = try did.requireID()
    self.nullified = nullified
    self.createdAt = createdAt
    self.$prev.id = try prev?.requireID()
    self.$handle.id = try handle.requireID()
    self.$pds.id = try pds.requireID()
  }
}
