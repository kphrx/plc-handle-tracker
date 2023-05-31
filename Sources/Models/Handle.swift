import Fluent
import Vapor

enum HandleNameError: Error {
  case invalidCharacter
}

final class Handle: Model, Content {
  static let schema = "handles"

  static let validDomainNameCharacters = CharacterSet(charactersIn: "a"..."z")
    .union(.init(charactersIn: "0"..."9"))
    .union(.init(charactersIn: ".-"))
    .inverted

  @ID(key: .id)
  var id: UUID?

  @Field(key: "handle")
  var handle: String

  @Children(for: \.$handle)
  var operations: [Operation]

  init() {}

  init(id: UUID? = nil, handle: String) throws {
    self.id = id
    if handle.rangeOfCharacter(from: Handle.validDomainNameCharacters) != nil {
      throw HandleNameError.invalidCharacter
    }
    self.handle = handle
  }
}
