import Vapor

func commands(_ app: Application) {
  app.commands.use(ImportAuditableLogCommand(), as: "import")
}
