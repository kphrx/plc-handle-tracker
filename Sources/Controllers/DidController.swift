import Fluent
import Vapor

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

  func show(req: Request) async throws -> Did {
    guard let did = req.parameters.get("did") else {
      throw Abort(.internalServerError)
    }
    guard let didPlc = try await Did.query(on: req.db).filter(\.$did == did).first() else {
      throw Abort(.notFound)
    }
    return didPlc
  }
}
