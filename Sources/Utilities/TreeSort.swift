import Foundation

extension Operation: TreeSort {
  typealias KeyType = Operation.IDValue
  func cursor() throws -> KeyType {
    try self.requireID()
  }
  func previousCursor() -> KeyType? {
    self.$prev.id
  }
}

extension ExportedOperation: TreeSort {
  typealias KeyType = String
  func cursor() -> KeyType {
    self.cid
  }
  func previousCursor() -> KeyType? {
    switch self.operation {
    case .create: nil
    case .plcOperation(let plcOp): plcOp.prev
    case .plcTombstone(let tombstoneOp): tombstoneOp.prev
    }
  }
}

protocol TreeSort {
  associatedtype KeyType: Hashable
  func cursor() throws -> KeyType
  func previousCursor() -> KeyType?
}

func treeSort<T: TreeSort>(_ array: [T]) throws -> [[T]] {
  var dict: [T.KeyType: T] = [:]
  var ids: [T.KeyType] = []
  var heads: [T] = []
  for item in array {
    ids.append(try item.cursor())
    guard let prev = item.previousCursor() else {
      heads.append(item)
      continue
    }
    if dict[prev] != nil {
      heads.append(item)
      continue
    }
    dict[prev] = item
  }
  for headId in dict.keys.filter({ !ids.contains($0) }) {
    if let head = dict[headId] {
      heads.append(head)
    }
  }
  if heads.isEmpty {
    throw "Invalid item tree"
  }
  return try heads.map { head in
    var result = [head]
    var currentId = try head.cursor()
    while let next = dict[currentId] {
      currentId = try next.cursor()
      result.append(next)
    }
    return result
  }
}
