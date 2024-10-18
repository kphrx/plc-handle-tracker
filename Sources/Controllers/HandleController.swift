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
  struct HandleUsagePeriod: Content {
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
  let operations: [HandleUsagePeriod]
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
    let (handleUsagePeriod, currents):
      ([HandleShowContext.HandleUsagePeriod], [HandleShowContext.Current]) =
        try await withThrowingTaskGroup(
          of: (Int, HandleShowContext.HandleUsagePeriod, HandleShowContext.Current?).self
        ) {
          let usagePeriod = try handle.nonNullifiedOperations.treeSort()
          for (i, ops) in usagePeriod.enumerated() {
            guard let firstOp = ops.first, let lastOp = ops.last else {
              continue
            }
            let did = firstOp.$id.$did.id
            $0.addTask {
              guard let untilOp = try await lastOp.$nexts.get(on: req.db).first else {
                return try await (
                  i, .init(did: did, createdAt: firstOp.createdAt, updatedAt: nil),
                  .init(did: did, pds: lastOp.$pds.get(on: req.db)!.endpoint)
                )
              }
              return (
                i, .init(did: did, createdAt: firstOp.createdAt, updatedAt: untilOp.createdAt), nil
              )
            }
          }
          return try await $0.reduce(into: Array(repeating: nil, count: usagePeriod.count)) {
            $0[$1.0] = ($1.1, $1.2)
          }.compactMap { $0 }.reduce(into: ([], [])) {
            if let current = $1.1 { $0.1.append(current) }
            $0.0.append($1.0)
          }
        }
    return try await req.view.render(
      "handle/show",
      HandleShowContext(
        title: "@\(handle.handle)", route: req.route?.description ?? "",
        current: currents, operations: handleUsagePeriod))
  }
}
