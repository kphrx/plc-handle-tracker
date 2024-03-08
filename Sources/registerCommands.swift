import Vapor

func registerCommands(_ app: Application) {
  app.commands.use(ImportDidCommand(), as: "import")
  app.commands.use(ImportExportedLogCommand(), as: "import-exported-log")
  app.commands.use(CleanupCacheCommand(), as: "cleanup-cache")
}
