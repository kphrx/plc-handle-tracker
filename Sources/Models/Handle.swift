import Fluent
import Vapor

enum HandleNameError: Error {
  case invalidCharacter
}

final class Handle: Model, Content, @unchecked Sendable {
  static let schema = "handles"

  static func findBy(handleName: String, withOp: Bool = false, on db: Database) async throws
    -> Handle?
  {
    let query = Handle.query(on: db).filter(\.$handle == handleName)
    return try await if withOp {
      query.with(\.$operations).first()
    } else {
      query.first()
    }
  }

  static let invalidDomainNameCharacters = CharacterSet(charactersIn: "a"..."z")
    .union(.init(charactersIn: "0"..."9"))
    .union(.init(charactersIn: ".-"))
    .inverted

  static func validate(_ handle: String) -> Bool {
    return handle.count > 3
      && handle.rangeOfCharacter(from: Self.invalidDomainNameCharacters) == nil
  }

  @ID(key: .id)
  var id: UUID?

  @Field(key: "handle")
  var handle: String

  @Children(for: \.$handle)
  var operations: [Operation]

  init() {}

  init(id: UUID? = nil, _ handle: String) throws {
    self.id = id
    if !Self.validate(handle) {
      throw HandleNameError.invalidCharacter
    }
    self.handle = handle
  }
}
