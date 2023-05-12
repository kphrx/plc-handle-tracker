import Vapor

func commands(_ app: Application) {
  app.commands.use(ImportDidCommand(), as: "import")
  app.commands.use(ImportExportedLogCommand(), as: "import-exported-log")
}
