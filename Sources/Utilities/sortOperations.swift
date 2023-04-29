import Foundation

func sortToTrees(op operations: [Operation]) throws -> [[Operation]] {
  var dict: [UUID: Operation] = [:]
  var ids: [UUID] = []
  var heads: [Operation] = []
  for operation in operations {
    ids.append(try operation.requireID())
    guard let prev = operation.$prev.id else {
      heads.append(operation)
      continue
    }
    if dict[prev] != nil {
      heads.append(operation)
      continue
    }
    dict[prev] = operation
  }
  for headId in dict.keys.filter({ !ids.contains($0) }) {
    if let head = dict[headId] {
      heads.append(head)
    }
  }
  guard heads.count > 0 else { throw "Invalid operation tree" }
  return try heads.map { head in
    var result = [head]
    var currentId = try head.requireID()
    while let nextOp = dict[currentId] {
      currentId = try nextOp.requireID()
      result.append(nextOp)
    }
    return result
  }
}

func sortByCreatedAt(op operations: [Operation]) -> [Operation] {
  return mergeSort(operations)
}
