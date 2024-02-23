import Vapor

func registerJobs(_ app: Application) {
  app.queues.add(ImportAuditableLogJob())
  app.queues.add(FetchDidJob())
  app.queues.add(ImportExportedLogJob())
  app.queues.add(PollingJobNotificationHook(on: app.db))
  app.queues.add(PollingPlcServerExportJob())

  let pollingInterval = Environment.get("POLLING_INTERVAL").flatMap(Int.init(_:)) ?? 30
  let pollingStart = Environment.get("POLLING_START_AT_MINUTES").flatMap(Int.init(_:)) ?? 20
  let afterRecovery = Environment.get("AFTER_POLLING_RECOVERLY_MINUTES").flatMap(Int.init(_:)) ?? 15
  app.queues.scheduleEvery(ScheduledPollingJob(), stride: pollingInterval, from: pollingStart)
  app.queues.scheduleEvery(
    ScheduledPollingRecoveryJob(), stride: pollingInterval, from: pollingStart + afterRecovery)

  if Environment.getBool("DISABLE_POLLING_HISTORY_CLEANUP") {
    return
  }
  let cleanupInterval =
    Environment.get("POLLING_HISTORY_CLEANUP_INTERVAL").flatMap(Int.init(_:)) ?? 15
  let cleanupStart =
    Environment.get("POLLING_HISTORY_CLEANUP_START_AT_MINUTES").flatMap(Int.init(_:)) ?? 10
  app.queues.scheduleEvery(
    ScheduledPollingHistoryCleanupJob(), stride: cleanupInterval, from: cleanupStart)
}
