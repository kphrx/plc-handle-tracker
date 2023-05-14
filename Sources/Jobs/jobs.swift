import Vapor

func jobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.schedule(PollingPlcServerExportJob()).hourly().at(21)
  app.queues.add(StorePollingJobStatus(on: app.db))
}
