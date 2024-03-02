import Foundation

protocol TreeSort {
  associatedtype KeyType: Hashable
  func cursor() throws -> KeyType
  func previousCursor() -> KeyType?
}

extension Array where Element: TreeSort {
  func treeSort() throws -> [Self] {
    var dict: [Element.KeyType: Element] = [:]
    var ids: [Element.KeyType] = []
    var heads: Self = []
    for item in self {
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
}
