import Fluent
import Vapor

struct DidResponse: Content {
  struct Current: Content {
    let handle: String
    let pds: String

    init?(op operation: Operation?) {
      guard let operation, let handle = operation.handle?.handle, let pds = operation.pds?.endpoint
      else {
        return nil
      }
      self.handle = handle
      self.pds = pds
    }
  }
  let did: String
  let current: Current?
  let operations: [Operation]
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
    let operations = try onlyUpdateHandle(op: try sortById(op: didPlc.operations))
    let res = DidResponse(
      did: didPlc.did, current: .init(op: operations.last), operations: operations)
    return try await req.view.render("did/show", res)
  }
}
