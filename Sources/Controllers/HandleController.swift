import Fluent
import FluentPostgresDriver
import Vapor

struct HandleIndexQuery: Content {
  let name: String?
}

enum HandleSearchResult {
  case notFound(_: String)
  case list(_: String, result: [Handle])
  case redirect(_: String)
  case none

  func list() -> [Handle] {
    switch self {
    case .list(_, let result): return result
    default: return []
    }
  }

  func message() -> String? {
    switch self {
    case .notFound(let handle): return "Not found: @\(handle)"
    case .list(let handle, let result) where result.isEmpty: return "Not found: @\(handle)*"
    case .list(let handle, result: _): return "Search: @\(handle)*"
    default: return nil
    }
  }

  func status() -> HTTPResponseStatus {
    switch self {
    case .notFound: return .notFound
    case .redirect: return .movedPermanently
    case .list(_, let result) where result.isEmpty: return .notFound
    case .list, .none: return .ok
    }
  }
}

struct HandleIndexContext: SearchContext {
  let title: String?
  let route: String
  let count: Int
  let currentValue: String?
  let message: String?
  let result: [Handle]
}

struct HandleShowContext: BaseContext {
  struct UpdateHandleOp: Content {
    let did: String
    let pds: String
    let createdAt: Date
    let updatedAt: Date?
  }

  struct Current: Content {
    let did: String
    let pds: String

    init?(op operation: UpdateHandleOp) {
      guard operation.updatedAt == nil else {
        return nil
      }
      self.did = operation.did
      self.pds = operation.pds
    }
  }

  let title: String?
  let route: String
  let current: [Current]
  let operations: [UpdateHandleOp]
}

struct HandleController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let handles = routes.grouped("handle")
    handles.get(use: index)
    handles.group(":handle") { handle in
      handle.get(use: show)
    }
  }

  func index(req: Request) async throws -> ViewOrRedirect {
    let query = try req.query.decode(HandleIndexQuery.self)
    let currentValue: String?
    let result: HandleSearchResult
    if let handle = query.name {
      result = try await search(handle: handle, on: req.db)
      currentValue = handle
    } else {
      result = .none
      currentValue = nil
    }
    if case .redirect(let handle) = result {
      return .redirect(to: "/handle/\(handle)")
    }
    let count = try await Handle.query(on: req.db).count()
    return .view(
      try await req.view.render(
        "handle/index",
        HandleIndexContext(
          title: "Handles", route: req.route?.description ?? "", count: count,
          currentValue: currentValue, message: result.message(), result: result.list())),
      status: result.status())
  }

  private func search(handle: String, on database: Database) async throws -> HandleSearchResult {
    if try await Handle.query(on: database).filter(\.$handle == handle).first() != nil {
      return .redirect(handle)
    }
    if handle.count <= 3 {
      return .notFound(handle)
    }
    let result: [Handle]
    if database is PostgresDatabase {
      result = try await Handle.query(on: database).filter(\.$handle >= handle).filter(
        \.$handle
          <= .custom(SQLFunction("CONCAT", args: SQLLiteral.string(handle), SQLLiteral.string("~")))
      ).all()
    } else {
      result = try await Handle.query(on: database).filter(\.$handle =~ handle).all()
    }
    return .list(handle, result: result)
  }

  func show(req: Request) async throws -> View {
    guard let handleName = req.parameters.get("handle") else {
      throw Abort(.internalServerError)
    }
    guard
      let handle = try await Handle.query(on: req.db).filter(\.$handle == handleName).with(
        \.$operations, { $0.with(\.$pds).with(\.$id.$did) }
      ).first()
    else {
      throw Abort(.notFound)
    }
    let handleId = try handle.requireID()
    var operations = [HandleShowContext.UpdateHandleOp]()
    var lastId: Operation.IDValue?
    for operation in mergeSort(handle.operations) {
      let prev = lastId
      lastId = try operation.requireID()
      if prev != nil && prev == operation.$prev.id {
        continue
      }
      let did = try operation.did.requireID()
      guard
        let untilOp = try await operation.did.$operations.query(on: req.db).filter(
          \.$createdAt > operation.createdAt
        ).filter(\.$handle.$id != handleId).first()
      else {
        let lastOp =
          try await operation.did.$operations.query(on: req.db).with(\.$pds).sort(
            \.$createdAt, .descending
          ).first() ?? operation
        operations.append(
          .init(
            did: did, pds: lastOp.pds!.endpoint, createdAt: operation.createdAt, updatedAt: nil))
        continue
      }
      try await untilOp.$pds.load(on: req.db)
      operations.append(
        .init(
          did: did, pds: untilOp.pds!.endpoint, createdAt: operation.createdAt,
          updatedAt: untilOp.createdAt))
    }
    return try await req.view.render(
      "handle/show",
      HandleShowContext(
        title: "@\(handle.handle)", route: req.route?.description ?? "",
        current: operations.compactMap { .init(op: $0) }, operations: operations))
  }
}
