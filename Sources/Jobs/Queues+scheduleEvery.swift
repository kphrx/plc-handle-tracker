import Queues
import Vapor

extension Application.Queues {
  func scheduleEvery(_ job: ScheduledJob, stride strideStep: Int.Stride, from: Int = 0) {
    let start = from % 60
    let strideStart =
      if strideStep >= start {
        strideStep - start
      } else {
        start
      }
    for minuteOffset in stride(from: strideStart, to: 60, by: strideStep) {
      self.schedule(job).hourly().at(.init(integerLiteral: minuteOffset))
    }
  }
}
