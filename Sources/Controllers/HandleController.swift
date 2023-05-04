import Fluent
import Vapor

struct HandleIndexQuery: Content {
  let name: String?
}

struct HandleIndexContext: Content {
  let title: String
  let count: Int
  let message: String?
}

struct HandleShowContext: Content {
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

  let title: String
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
    let query = try req.query.decode(DidIndexQuery.self)
    let message: String?
    if let handle = query.name {
      if try await Handle.query(on: req.db).filter(\.$handle == handle).first() != nil {
        return .redirect(to: "/handle/\(handle)")
      }
      message = "Not found handle: @\(handle)"
    } else {
      message = nil
    }
    let count = try await Did.query(on: req.db).count()
    return .view(try await req.view.render("handle/index", DidIndexContext(title: "Handles", count: count, message: message)))
  }

  func show(req: Request) async throws -> View {
    guard let handleName = req.parameters.get("handle") else {
      throw Abort(.internalServerError)
    }
    guard
      let handle = try await Handle.query(on: req.db).filter(\.$handle == handleName).with(
        \.$operations,
        { operations in
          operations.with(\.$pds).with(\.$did) { did in
            did.with(\.$operations) { operations in operations.with(\.$handle) }
          }
        }
      ).first()
    else {
      throw Abort(.notFound)
    }
    let operations = try mergeSort(handle.operations).compactMap {
      operation -> HandleShowContext.UpdateHandleOp? in
      guard let didOps = try treeSort(operation.did.operations).first else {
        throw "Broken operation tree"
      }
      let updateHandleOps = try onlyUpdateHandle(op: didOps)
      guard let since = updateHandleOps.firstIndex(where: { $0.id == operation.id }) else {
        return nil
      }
      var until: Operation? = nil
      if since < updateHandleOps.indices.last! {
        until = updateHandleOps[since + 1]
      }
      return .init(
        did: try operation.did.requireID(), pds: operation.pds!.endpoint,
        createdAt: operation.createdAt, updatedAt: until?.createdAt)
    }
    return try await req.view.render(
      "handle/show",
      HandleShowContext(
        title: "@\(handle.handle)", current: operations.compactMap { .init(op: $0) },
        operations: operations))
  }
}
