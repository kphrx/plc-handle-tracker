import Vapor

func registerMiddleware(_ app: Application) {
  app.middleware = .init()
  app.middleware.use(RouteLoggingMiddleware())
  app.middleware.use(ErrorMiddleware(environment: app.environment))
  // serve files from /Public folder
  app.middleware.use(
    FileMiddleware(publicDirectory: app.directory.publicDirectory, directoryAction: .redirect))

  // database middleware
  app.databases.middleware.use(DidMiddleware(redis: app.redis, logger: app.logger), on: .psql)
}
