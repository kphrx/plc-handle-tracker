import Fluent
import FluentPostgresDriver
import QueuesRedisDriver
import Vapor

func registerCustomCoder() {
  // milliseconds RFC 3339 FormatStyle
  let formatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

  let encoder = JSONEncoder.custom(
    dates: .custom({ (date, encoder) in
      var container = encoder.singleValueContainer()
      try container.encode(date.formatted(formatStyle))
    }))
  ContentConfiguration.global.use(encoder: encoder, for: .json)
  ContentConfiguration.global.use(encoder: encoder, for: .jsonAPI)

  let decoder = JSONDecoder.custom(
    dates: .custom({ decoder in
      let container = try decoder.singleValueContainer()
      let string = try container.decode(String.self)
      do {
        return try formatStyle.parse(string)
      } catch {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Expected date string to be ISO8601-formatted."))
      }
    }))
  ContentConfiguration.global.use(decoder: decoder, for: .json)
  ContentConfiguration.global.use(decoder: decoder, for: .jsonAPI)
}

func connectDatabase(_ app: Application) {
  app.databases.use(
    .postgres(
      configuration: .init(
        hostname: Environment.get("DATABASE_HOST", "localhost"),
        port: Environment.getInt("DATABASE_PORT", SQLPostgresConfiguration.ianaPortNumber),
        username: Environment.get("DATABASE_USERNAME", "vapor_username"),
        password: Environment.get("DATABASE_PASSWORD", "vapor_password"),
        database: Environment.get("DATABASE_NAME", "vapor_database"), tls: .disable),
      connectionPoolTimeout: .seconds(60)), as: .psql)
}

func connectRedis(_ app: Application) throws {
  app.redis.configuration = try .init(
    url: Environment.get("REDIS_URL", "redis://localhost:6379"),
    pool: .init(connectionRetryTimeout: .seconds(60)))
}

func startJobQueuing(_ app: Application) throws {
  app.queues.use(.redis(app.redis.configuration!))

  if Environment.getBool("INPROCESS_JOB") {
    try app.queues.startInProcessJobs(on: .default)
    try app.queues.startInProcessJobs(on: .polling)
    try app.queues.startScheduledJobs()
  }
}

// configures your application
public func configure(_ app: Application) async throws {
  connectDatabase(app)
  try connectRedis(app)

  app.caches.use(.redis)

  registerCustomCoder()
  registerMigrations(app)
  registerJobs(app)
  registerCommands(app)
  registerViews(app)
  registerMiddleware(app)

  try registerRoutes(app)

  try startJobQueuing(app)
}
