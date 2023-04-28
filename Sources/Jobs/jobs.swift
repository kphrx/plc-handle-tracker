import Vapor

func jobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
}
