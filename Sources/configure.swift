import Fluent
import FluentPostgresDriver
import QueuesRedisDriver
import Vapor

func registerCustomCoder() {
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

func startJobQueuing(_ app: Application) throws {
  try app.queues.use(
    .redis(
      .init(
        url: Environment.get("REDIS_URL", "redis://localhost:6379"),
        pool: .init(connectionRetryTimeout: .seconds(60)))))

  if Environment.getBool("INPROCESS_JOB") {
    try app.queues.startInProcessJobs(on: .default)
    try app.queues.startInProcessJobs(on: .polling)
    try app.queues.startScheduledJobs()
  }
}

// configures your application
public func configure(_ app: Application) async throws {
  connectDatabase(app)

  registerCustomCoder()
  registerMigrations(app)
  registerJobs(app)
  registerCommands(app)
  registerViews(app)
  registerMiddleware(app)

  try routes(app)

  try startJobQueuing(app)
}
