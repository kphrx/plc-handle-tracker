import Fluent
import Vapor

struct DidIndexQuery: Content {
  let did: String?
  let specificId: String?

  private enum CodingKeys: String, CodingKey {
    case did
    case specificId = "specific_id"
  }
}

enum DidSearchResult {
  case notFound(_: String)
  case invalidFormat(_: String)
  case redirect(_: String)
  case none

  var message: String? {
    switch self {
      case .notFound(let did): "Not found: \(did)"
      case .invalidFormat(let did): "Invalid DID format: \(did)"
      default: nil
    }
  }

  var status: HTTPResponseStatus {
    switch self {
      case .notFound: .notFound
      case .invalidFormat: .badRequest
      case .redirect: .movedPermanently
      case .none: .ok
    }
  }
}

struct DidIndexContext: SearchContext {
  let title: String?
  let route: String
  let count: Int
  let currentValue: String?
  let message: String?
}

struct DidShowContext: BaseContext {
  struct UpdateHandleOp: Content {
    let handle: String?
    let createdAt: Date

    init(op operation: Operation, on db: Database) async throws {
      let handle = try await operation.$handle.get(on: db)
      self.handle = handle?.handle
      self.createdAt = operation.createdAt
    }
  }

  struct Current: Content {
    let handle: String
    let pds: String

    init?(op operation: Operation?, on db: Database) async throws {
      guard let operation else {
        return nil
      }
      let (handle, pds) = try await (operation.$handle.get(on: db), operation.$pds.get(on: db))
      guard let handleName = handle?.handle, let pdsEndpoint = pds?.endpoint else {
        return nil
      }
      self.handle = handleName
      self.pds = pdsEndpoint
    }
  }

  let title: String?
  let route: String
  let current: Current?
  let operations: [UpdateHandleOp]
}

struct DidController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let dids = routes.grouped("did")
    dids.get(use: index)
    dids.group(":did") { $0.get(use: show) }
  }

  func index(req: Request) async throws -> ViewOrRedirect {
    let query = try req.query.decode(DidIndexQuery.self)
    let (specificId, did) =
      query.specificId.map({ ($0, "did:plc:" + $0) }) ?? query.did.map({
        (String($0.trimmingPrefix("did:plc:")), $0)
      }) ?? (nil, nil)
    let result: DidSearchResult =
      if let did {
        try await self.search(did: did, req: req)
      } else {
        .none
      }
    if case .redirect(let did) = result {
      return .redirect(to: "/did/\(did)", redirectType: .permanent)
    }
    let count = try await req.didRepository.count()
    return .view(
      try await req.view.render(
        "did/index",
        DidIndexContext(
          title: "DID Placeholders", route: req.route?.description ?? "", count: count,
          currentValue: specificId, message: result.message)), status: result.status)
  }

  private func search(did: String, req: Request) async throws -> DidSearchResult {
    if !Did.validate(did: did) {
      .invalidFormat(did)
    } else if try await req.didRepository.search(did: did) {
      .redirect(did)
    } else {
      .notFound(did)
    }
  }

  func show(req: Request) async throws -> View {
    guard let did = req.parameters.get("did") else {
      throw Abort(.internalServerError)
    }
    guard Did.validate(did: did) else {
      throw Abort(.badRequest, reason: "Invalid DID format")
    }
    guard let didPlc = try await req.didRepository.findOrFetch(did) else {
      throw Abort(.notFound)
    }
    if didPlc.banned {
      throw Abort(.notFound, reason: didPlc.reason?.rawValue)
    }
    if didPlc.nonNullifiedOperations.isEmpty {
      throw Abort(.notFound, reason: "Operation not stored")
    }
    guard let operations = try didPlc.nonNullifiedOperations.treeSort().first else {
      throw Abort(.internalServerError, reason: "Broken operation tree")
    }
    let updateHandleOps = try await withThrowingTaskGroup(
      of: (idx: Int, op: DidShowContext.UpdateHandleOp).self
    ) {
      let updateHandleOps = try operations.onlyUpdateHandle()
      for (i, op) in updateHandleOps.enumerated() {
        $0.addTask { try await (i, .init(op: op, on: req.db)) }
      }
      return
        try await $0.reduce(into: Array(repeating: nil, count: updateHandleOps.count)) {
          $0[$1.idx] = $1.op
        }
        .compactMap { $0 }
    }
    return try await req.view.render(
      "did/show",
      DidShowContext(
        title: didPlc.requireID(), route: req.route?.description ?? "",
        current: .init(op: operations.last, on: req.db), operations: updateHandleOps))
  }
}
