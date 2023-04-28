import Fluent
import FluentPostgresDriver
import Leaf
import QueuesRedisDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
  // milliseconds RFC 3339 encoder/decoder
  let dateFormatter = ISO8601DateFormatter()
  dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

  let encode = { (_ data: Date, _ encoder: Encoder) throws -> Void in
    var container = encoder.singleValueContainer()
    try container.encode(dateFormatter.string(from: data))
  }
  ContentConfiguration.global.use(encoder: JSONEncoder.custom(dates: .custom(encode)), for: .json)
  ContentConfiguration.global.use(
    encoder: JSONEncoder.custom(dates: .custom(encode)), for: .jsonAPI)

  let decode = { (_ decoder: Decoder) throws -> Date in
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let date = dateFormatter.date(from: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Expected date string to be ISO8601-formatted."))
    }
    return date
  }
  ContentConfiguration.global.use(decoder: JSONDecoder.custom(dates: .custom(decode)), for: .json)
  ContentConfiguration.global.use(
    decoder: JSONDecoder.custom(dates: .custom(decode)), for: .jsonAPI)

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
