import Fluent
import Vapor

func migrations(_ app: Application) {
  app.migrations.add(CreateDidsTable())
  app.migrations.add(CreateHandlesTable())
  app.migrations.add(CreatePersonalDataServersTable())
  app.migrations.add(CreateOperationsTable())
  app.migrations.add(CreatePollingHistoryTable())
  app.migrations.add(AddFailedColumnToPollingHistoryTable())
  app.migrations.add(AddCompletedColumnToPollingHistoryTable())
  app.migrations.add(ChangePrimaryKeyToNaturalKeyOfDidAndCid())
  app.migrations.add(CreatePollingJobStatusesTable())
  app.migrations.add(ChangeToNullableCidAndCreatedAtColumn())
  app.migrations.add(AddDidColumnToPollingJobStatusesTable())
  app.migrations.add(CreateBannedDidsTable())
}
