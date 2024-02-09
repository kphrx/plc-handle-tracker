import Vapor

func jobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.add(PollingJobNotificationHook(on: app.db))
  app.queues.add(PollingPlcServerExportJob())

  app.queues.scheduleEvery(ScheduledPollingRecoveryJob(), stride: 30, from: 5)
  app.queues.scheduleEvery(ScheduledPollingHistoryCleanupJob(), stride: 15, from: 10)
  app.queues.scheduleEvery(ScheduledPollingJob(), stride: 30, from: 20)
}
