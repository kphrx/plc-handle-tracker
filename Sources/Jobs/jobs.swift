import Vapor

func jobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.add(PollingPlcServerExportJob())

  app.queues.add(PollingJobNotificationHook(on: app.db))
  app.queues.add(FetchDidJobNotificationHook(on: app.db))

  app.queues.schedule(ScheduledPollingRecoveryJob()).hourly().at(5)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(10)
  app.queues.schedule(ScheduledPollingJob()).hourly().at(20)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(25)
  app.queues.schedule(ScheduledPollingRecoveryJob()).hourly().at(35)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(40)
  app.queues.schedule(ScheduledPollingJob()).hourly().at(50)
  app.queues.schedule(ScheduledPollingHistoryCleanupJob()).hourly().at(55)
}
