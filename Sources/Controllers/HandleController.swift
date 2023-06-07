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

  var list: [Handle] {
    switch self {
    case .list(_, let result): result
    default: []
    }
  }

  var message: String? {
    switch self {
    case .notFound(let handle): "Not found: @\(handle)"
    case .list(let handle, let result) where result.isEmpty: "Not found: @\(handle)*"
    case .list(let handle, result: _): "Search: @\(handle)*"
    default: nil
    }
  }

  var status: HTTPResponseStatus {
    switch self {
    case .notFound: .notFound
    case .redirect: .movedPermanently
    case .list(_, let result) where result.isEmpty: .notFound
    case .list, .none: .ok
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
    let result: HandleSearchResult =
      if let handle = query.name {
        try await search(handle: handle, on: req.db)
      } else {
        .none
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
          currentValue: query.name, message: result.message, result: result.list)),
      status: result.status)
  }

  private func search(handle: String, on database: Database) async throws -> HandleSearchResult {
    if try await Handle.query(on: database).filter(\.$handle == handle).first() != nil {
      return .redirect(handle)
    }
    if handle.count <= 3 {
      return .notFound(handle)
    }
    let result: [Handle] =
      if database is PostgresDatabase {
        try await Handle.query(on: database).filter(\.$handle >= handle).filter(
          \.$handle
            <= .custom(
              SQLFunction("CONCAT", args: SQLLiteral.string(handle), SQLLiteral.string("~")))
        ).all()
      } else {
        try await Handle.query(on: database).filter(\.$handle =~ handle).all()
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
