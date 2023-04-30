import Vapor

func commands(_ app: Application) {
  app.commands.use(ImportDidCommand(), as: "import")
  app.commands.use(ImportExportLogCommand(), as: "import-export-log")
}
