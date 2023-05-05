import Fluent
import Vapor

struct DidIndexQuery: Content {
  let name: String?
}

struct DidIndexContext: Content {
  let title: String
  let count: Int
  let message: String?
}

struct DidShowContext: Content {
  struct UpdateHandleOp: Content {
    let handle: String?
    let pds: String?
    let createdAt: Date
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

  let title: String
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
    let message: String?
    if let did = query.name {
      if validateDidPlaceholder(did) {
        if try await Did.find(did, on: req.db) != nil {
          return .redirect(to: "/did/\(did)")
        }
        message = "Not found: \(did)"
      } else if validateDidPlaceholder("did:plc:" + did) {
        let did = "did:plc:" + did
        if try await Did.find(did, on: req.db) != nil {
          return .redirect(to: "/did/\(did)")
        }
        message = "Not found: \(did)"
      } else {
        message = "Invalid DID format: \(did)"
      }
    } else {
      message = nil
    }
    let count = try await Did.query(on: req.db).count()
    return .view(
      try await req.view.render(
        "did/index", DidIndexContext(title: "DID Placeholders", count: count, message: message)))
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
    guard let operations = try treeSort(didPlc.operations).first else {
      throw "Broken operation tree"
    }
    let updateHandleOps = try onlyUpdateHandle(op: operations).map {
      operation -> DidShowContext.UpdateHandleOp in
      return .init(
        handle: operation.handle?.handle, pds: operation.pds?.endpoint,
        createdAt: operation.createdAt)
    }
    return try await req.view.render(
      "did/show",
      DidShowContext(
        title: try didPlc.requireID(), current: .init(op: updateHandleOps.last),
        operations: updateHandleOps))
  }
}
