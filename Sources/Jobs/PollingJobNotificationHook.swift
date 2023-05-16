import Fluent
import Foundation
import Queues

struct PollingJobNotificationHook: AsyncJobEventDelegate {
  typealias Job = ImportExportedLogJob

  let database: Database

  init(on database: Database) {
    self.database = database
  }

  func dispatched(job: JobEventData) async throws {
    guard let jobId = UUID(uuidString: job.id), job.jobName == String(describing: Job.self) else {
      return
    }
    let payload = try Job.parsePayload(job.payload)
    try await PollingJobStatus(
      id: jobId, historyId: payload.historyId, dispatchTimestamp: job.queuedAt
    ).create(on: self.database)
  }

  func didDequeue(jobId: String) async throws {
    guard let jobId = UUID(uuidString: jobId),
      let jobStatus = try await PollingJobStatus.find(jobId, on: self.database)
    else {
      return
    }
    jobStatus.dequeuedAt = Date()
    jobStatus.status = .running
    try await jobStatus.update(on: self.database)
  }

  func success(jobId: String) async throws {
    guard let jobId = UUID(uuidString: jobId),
      let jobStatus = try await PollingJobStatus.find(jobId, on: self.database)
    else {
      return
    }
    jobStatus.completedAt = Date()
    jobStatus.status = .success
    try await jobStatus.update(on: self.database)
  }

  func error(jobId: String, error: Error) async throws {
    guard let jobId = UUID(uuidString: jobId),
      let jobStatus = try await PollingJobStatus.find(jobId, on: self.database)
    else {
      return
    }
    jobStatus.completedAt = Date()
    jobStatus.status = .error
    try await jobStatus.update(on: self.database)
  }
}
