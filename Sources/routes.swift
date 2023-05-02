import Fluent
import Vapor

func routes(_ app: Application) throws {
  app.get { req in
    try await req.view.render("index")
  }

  try app.register(collection: DidController())
  try app.register(collection: HandleController())
}
