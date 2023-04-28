import Foundation

func sortById(op operations: [Operation]) throws -> [Operation] {
  var dict: [UUID: Operation] = [:]
  var head: Operation?
  for operation in operations {
    guard let prev = operation.$prev.id else {
      head = operation
      continue
    }
    dict[prev] = operation
  }
  guard let start = head else { return [] }
  var result = [start]
  var currentId = try start.requireID()
  while let nextOp = dict[currentId] {
    currentId = try nextOp.requireID()
    result.append(nextOp)
  }
  return result
}
