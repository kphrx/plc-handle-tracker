import Fluent
import Vapor

struct HandleController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let handles = routes.grouped("handle")
    handles.get(use: index)
    handles.group(":handle") { handle in
      handle.get(use: show)
    }
  }

  func index(req: Request) async throws -> [Handle] {
    try await Handle.query(on: req.db).all()
  }

  func show(req: Request) async throws -> Handle {
    guard let handleName = req.parameters.get("handle") else {
      throw Abort(.internalServerError)
    }
    guard let handle = try await Handle.query(on: req.db).filter(\.$handle == handleName).first()
    else {
      throw Abort(.notFound)
    }
    return handle
  }
}
