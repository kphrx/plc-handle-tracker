import Vapor

func middleware(_ app: Application) {
  app.middleware.use(ErrorMiddleware(environment: app.environment))

  // serve files from /Public folder
  app.middleware.use(
    FileMiddleware(publicDirectory: app.directory.publicDirectory, directoryAction: .redirect))
}
