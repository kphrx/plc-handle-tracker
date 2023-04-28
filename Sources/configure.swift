import Fluent
import FluentPostgresDriver
import Leaf
import QueuesRedisDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
  // uncomment to serve files from /Public folder
  // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

  app.databases.use(
    .postgres(
      hostname: Environment.get("DATABASE_HOST") ?? "localhost",
      port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:))
        ?? PostgresConfiguration.ianaPortNumber,
      username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
      password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
      database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)
  migrations(app)

  try app.queues.use(.redis(url: Environment.get("REDIS_URL") ?? "redis://localhost:6379"))
  // register jobs
  jobs(app)

  if (Environment.get("INPROCESS_JOB") ?? "false") == "true" {
    try app.queues.startInProcessJobs(on: .default)
    try app.queues.startScheduledJobs()
  }

  app.views.use(.leaf)

  // register commands
  commands(app)

  // register routes
  try routes(app)
}
