import Vapor

func registerJobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.add(PollingJobNotificationHook(on: app.db))
  app.queues.add(PollingPlcServerExportJob())

  let pollingInterval = Environment.getInt("POLLING_INTERVAL", 30)
  let pollingStart = Environment.getInt("POLLING_START_AT_MINUTES", 20)
  let afterRecovery = Environment.getInt("AFTER_POLLING_RECOVERLY_MINUTES", 15)
  app.queues.scheduleEvery(ScheduledPollingJob(), stride: pollingInterval, from: pollingStart)
  app.queues.scheduleEvery(
    ScheduledPollingRecoveryJob(), stride: pollingInterval, from: pollingStart + afterRecovery)

  if Environment.getBool("DISABLE_POLLING_HISTORY_CLEANUP") {
    return
  }
  let cleanupInterval = Environment.getInt("POLLING_HISTORY_CLEANUP_INTERVAL", 15)
  let cleanupStart = Environment.getInt("POLLING_HISTORY_CLEANUP_START_AT_MINUTES", 10)
  app.queues.scheduleEvery(
    ScheduledPollingHistoryCleanupJob(), stride: cleanupInterval, from: cleanupStart)
}
