import Vapor

func jobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.add(PollingJobNotificationHook(on: app.db))
  app.queues.add(PollingPlcServerExportJob())

  app.queues.schedule(ScheduledPollingJob()).hourly().at(21)
  app.queues.schedule(ScheduledPollingJob()).hourly().at(51)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(25)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(40)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(55)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(10)
}
