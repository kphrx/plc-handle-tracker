import Fluent
import Vapor

struct DidResponse: Content {
  struct UpdateHandleOperation: Content {
    let handle: String?
    let pds: String?
    let createdAt: Date
  }

  struct Current: Content {
    let handle: String
    let pds: String

    init?(op operation: UpdateHandleOperation?) {
      guard let operation, let handle = operation.handle, let pds = operation.pds else {
        return nil
      }
      self.handle = handle
      self.pds = pds
    }
  }

  let title: String
  let current: Current?
  let operations: [UpdateHandleOperation]
}

struct DidController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let dids = routes.grouped("did")
    dids.get(use: index)
    dids.group(":did") { did in
      did.get(use: show)
    }
  }

  func index(req: Request) async throws -> [Did] {
    try await Did.query(on: req.db).all()
  }

  func show(req: Request) async throws -> View {
    guard let did = req.parameters.get("did") else {
      throw Abort(.internalServerError)
    }
    if !validateDidPlaceholder(did) {
      throw Abort(.badRequest, reason: "Invalid DID Placeholder")
    }
    guard
      let didPlc = try await Did.query(on: req.db).filter(\.$did == did).with(
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
      operation -> DidResponse.UpdateHandleOperation in
      return .init(
        handle: operation.handle?.handle, pds: operation.pds?.endpoint,
        createdAt: operation.createdAt)
    }
    let res = DidResponse(
      title: didPlc.did, current: .init(op: updateHandleOps.last), operations: updateHandleOps)
    return try await req.view.render("did/show", res)
  }
}
