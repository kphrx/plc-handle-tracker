import Fluent
import Vapor

final class Operation: Model, Content {
  static let schema = "operations"

  @ID(custom: "cid", generatedBy: .user)
  var id: String?

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

  @OptionalParent(key: "handle")
  var handle: Handle?

  @OptionalParent(key: "pds")
  var pds: PersonalDataServer?

  init() {}

  init(
    cid: String, did: String, nullified: Bool, createdAt: Date,
    prev: Operation? = nil, handle: Handle? = nil, pds: PersonalDataServer? = nil
  ) throws {
    self.id = cid
    self.$did.id = did
    self.nullified = nullified
    self.createdAt = createdAt
    self.$prev.id = try prev?.requireID()
    self.$handle.id = try handle?.requireID()
    self.$pds.id = try pds?.requireID()
  }
}
