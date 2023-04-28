import Foundation

func onlyUpdateHandle(op operations: [Operation]) throws -> [Operation] {
  var result = [Operation]()
  var previous: UUID?
  for operation in operations {
    let handleId = operation.handle?.id
    if handleId != previous || previous == nil {
      result.append(operation)
    }
    previous = handleId
  }
  return result
}
