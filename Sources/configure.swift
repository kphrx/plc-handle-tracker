import Fluent
import FluentPostgresDriver
import QueuesRedisDriver
import Vapor

func customCoder() {
  // milliseconds RFC 3339 encoder/decoder
  let dateFormatter = ISO8601DateFormatter()
  dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

  let encoder = JSONEncoder.custom(
    dates: .custom({ (date, encoder) in
      var container = encoder.singleValueContainer()
      try container.encode(dateFormatter.string(from: date))
    }))
  ContentConfiguration.global.use(encoder: encoder, for: .json)
  ContentConfiguration.global.use(encoder: encoder, for: .jsonAPI)

  let decoder = JSONDecoder.custom(
    dates: .custom({ decoder in
      let container = try decoder.singleValueContainer()
      let string = try container.decode(String.self)
      guard let date = dateFormatter.date(from: string) else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Expected date string to be ISO8601-formatted."))
      }
      return date
    }))
  ContentConfiguration.global.use(decoder: decoder, for: .json)
  ContentConfiguration.global.use(decoder: decoder, for: .jsonAPI)
}

func databaseConfig(_ app: Application) {
  app.databases.use(
    .postgres(
      hostname: Environment.get("DATABASE_HOST") ?? "localhost",
      port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:))
        ?? PostgresConfiguration.ianaPortNumber,
      username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
      password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
      database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)

  // register migrations
  migrations(app)
}

func jobQueueConfig(_ app: Application) throws {
  try app.queues.use(
    .redis(
      .init(
        url: Environment.get("REDIS_URL") ?? "redis://localhost:6379",
        pool: .init(connectionRetryTimeout: .seconds(60)))))

  // register jobs
  jobs(app)

  if (Environment.get("INPROCESS_JOB") ?? "false") == "true" {
    try app.queues.startInProcessJobs(on: .default)
    try app.queues.startScheduledJobs()
  }
}

// configures your application
public func configure(_ app: Application) async throws {
  customCoder()

  databaseConfig(app)

  try jobQueueConfig(app)

  // register commands
  commands(app)

  // register views
  views(app)

  app.middleware.use(ErrorMiddleware(environment: app.environment))

  // serve files from /Public folder
  app.middleware.use(
    FileMiddleware(publicDirectory: app.directory.publicDirectory, directoryAction: .redirect))

  // register routes
  try routes(app)
}
