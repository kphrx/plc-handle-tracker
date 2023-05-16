import Vapor

func jobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.add(PollingJobNotificationHook(on: app.db))
  app.queues.add(PollingPlcServerExportJob())
  app.queues.schedule(ScheduledPollingJob()).hourly().at(21)
}
