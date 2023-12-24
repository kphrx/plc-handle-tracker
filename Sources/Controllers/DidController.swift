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
    let pds: String?
    let createdAt: Date

    init?(op operation: Operation?) {
      guard let operation else {
        return nil
      }
      self.init(op: operation)
    }

    init(op operation: Operation) {
      self.handle = operation.handle?.handle
      self.pds = operation.pds?.endpoint
      self.createdAt = operation.createdAt
    }
  }

  struct Current: Content {
    let handle: String
    let pds: String

    init?(op operation: UpdateHandleOp?) {
      guard let operation, let handle = operation.handle, let pds = operation.pds else {
        return nil
      }
      self.handle = handle
      self.pds = pds
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
    dids.group(":did") { did in
      did.get(use: show)
    }
  }

  func index(req: Request) async throws -> ViewOrRedirect {
    let query = try req.query.decode(DidIndexQuery.self)
    let result: DidSearchResult =
      if let did = query.did {
        try await search(did: did, on: req.db)
      } else if let specificId = query.specificId {
        try await search(did: "did:plc:" + specificId, on: req.db)
      } else {
        .none
      }
    let currentValue: String? =
      query.specificId ?? query.did.map({ String($0.trimmingPrefix("did:plc:")) })
    if case .redirect(let did) = result {
      return .redirect(to: "/did/\(did)")
    }
    let count = try await Did.query(on: req.db).count()
    return .view(
      try await req.view.render(
        "did/index",
        DidIndexContext(
          title: "DID Placeholders", route: req.route?.description ?? "", count: count,
          currentValue: currentValue, message: result.message)), status: result.status)
  }

  private func search(did: String, on database: Database) async throws -> DidSearchResult {
    if !validateDidPlaceholder(did) {
      return .invalidFormat(did)
    }
    if try await Did.find(did, on: database) != nil {
      return .redirect(did)
    }
    return .notFound(did)
  }

  func show(req: Request) async throws -> View {
    guard let did = req.parameters.get("did") else {
      throw Abort(.internalServerError)
    }
    if !validateDidPlaceholder(did) {
      throw Abort(.badRequest, reason: "Invalid DID format")
    }
    guard
      let didPlc = try await Did.query(on: req.db).filter(\.$id == did).with(
        \.$operations, { operation in operation.with(\.$handle).with(\.$pds) }
      ).first()
    else {
      do {
        try await req.queue.dispatch(FetchDidJob.self, did)
      } catch {
        req.logger.report(error: error)
      }
      throw Abort(.notFound)
    }
    if didPlc.banned {
      throw Abort(.notFound, reason: didPlc.reason?.rawValue)
    }
    if didPlc.operations.isEmpty {
      throw Abort(.notFound, reason: "Operation not stored")
    }
    guard let operations = try treeSort(didPlc.operations).first else {
      throw Abort(.internalServerError, reason: "Broken operation tree")
    }
    let updateHandleOps = try onlyUpdateHandle(op: operations).map {
      DidShowContext.UpdateHandleOp(op: $0)
    }
    return try await req.view.render(
      "did/show",
      DidShowContext(
        title: try didPlc.requireID(), route: req.route?.description ?? "",
        current: .init(op: .init(op: operations.last)), operations: updateHandleOps))
  }
}
