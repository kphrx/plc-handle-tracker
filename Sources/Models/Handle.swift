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
    guard let handle = try await Handle.query(on: db).filter(\.$handle == handleName).first() else {
      return nil
    }
    if withOp {
      try await handle.loadNonNullifiedOps(on: db)
    }
    return handle
  }

  static let invalidDomainNameCharacters = CharacterSet(charactersIn: "a"..."z")
    .union(.init(charactersIn: "0"..."9")).union(.init(charactersIn: ".-")).inverted

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

  private var operationsCache: [Operation]?

  var nonNullifiedOperations: [Operation] {
    guard let ops = self.operationsCache else {
      fatalError("not eager loaded: nonNullifiedOperations")
    }
    return ops
  }

  init() {}

  init(id: UUID? = nil, _ handle: String) throws {
    self.id = id
    guard Self.validate(handle) else {
      throw HandleNameError.invalidCharacter
    }
    self.handle = handle
  }

  func loadNonNullifiedOps(on db: Database) async throws {
    self.operationsCache = try await Operation.query(on: db)
      .filter(\.$handle.$id == self.requireID()).filter(\.$nullified == false).all()
  }
}
