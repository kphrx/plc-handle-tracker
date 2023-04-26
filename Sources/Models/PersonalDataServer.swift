import Fluent
import Vapor

final class PersonalDataServer: Model, Content {
  static let schema = "personal_data_servers"

  @ID(key: .id)
  var id: UUID?

  @Field(key: "endpoint")
  var endpoint: String

  @Children(for: \.$pds)
  var operations: [Operation]

  init() {}

  init(id: UUID? = nil, endpoint: String) {
    self.id = id
    self.endpoint = endpoint
  }
}
