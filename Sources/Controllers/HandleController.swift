import Fluent
import FluentPostgresDriver
import Vapor

struct HandleIndexQuery: Content {
  let name: String?
}

enum HandleSearchResult {
  case invalid(_: String)
  case list(_: String, result: [String])
  case none

  var list: [String] {
    switch self {
    case .list(_, let result): result
    default: []
    }
  }

  var message: String? {
    switch self {
    case .invalid(let handle): "Invalid pattern: @\(handle)"
    case .list(let handle, let result) where result.isEmpty: "Not found: @\(handle)*"
    case .list(let handle, result: _): "Search: @\(handle)*"
    default: nil
    }
  }

  var status: HTTPResponseStatus {
    switch self {
    case .invalid: .badRequest
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
  let result: [String]
}

struct HandleShowContext: BaseContext {
  struct HandleUsedRange: Content {
    let did: String
    let createdAt: Date
    let updatedAt: Date?
  }

  struct Current: Content {
    let did: String
    let pds: String
  }

  let title: String?
  let route: String
  let current: [Current]
  let operations: [HandleUsedRange]
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
    if let handle = query.name, try await req.handleRepository.exists(handle) {
      return .redirect(to: "/handle/\(handle)", redirectType: .permanent)
    }
    async let count = req.handleRepository.count()
    async let result = self.search(handle: query.name, repo: req.handleRepository)
    return try await .view(
      req.view.render(
        "handle/index",
        HandleIndexContext(
          title: "Handles", route: req.route?.description ?? "", count: count,
          currentValue: query.name, message: result.message, result: result.list)),
      status: result.status)
  }

  private func search(handle: String?, repo: HandleRepository) async throws -> HandleSearchResult {
    guard let handle else {
      return .none
    }
    return switch try await repo.search(prefix: handle) {
    case .some(let result): .list(handle, result: result)
    case .none: .invalid(handle)
    }
  }

  func show(req: Request) async throws -> View {
    guard let handleName = req.parameters.get("handle") else {
      throw Abort(.internalServerError)
    }
    guard let handle = try await req.handleRepository.findWithOperations(handleName: handleName)
    else {
      throw Abort(.notFound)
    }
    var currents: [HandleShowContext.Current] = []
    var handleUsedRange: [HandleShowContext.HandleUsedRange] = []
    for ops in try handle.operations.treeSort() {
      guard let firstOp = ops.first, let lastOp = ops.last else {
        continue
      }
      let did = firstOp.$id.$did.id
      guard let untilOp = try await lastOp.$nexts.get(on: req.db).first else {
        try await currents.append(.init(did: did, pds: lastOp.$pds.get(on: req.db)!.endpoint))
        handleUsedRange.append(.init(did: did, createdAt: firstOp.createdAt, updatedAt: nil))
        continue
      }
      handleUsedRange.append(
        .init(did: did, createdAt: firstOp.createdAt, updatedAt: untilOp.createdAt))
    }
    return try await req.view.render(
      "handle/show",
      HandleShowContext(
        title: "@\(handle.handle)", route: req.route?.description ?? "",
        current: currents, operations: handleUsedRange))
  }
}
