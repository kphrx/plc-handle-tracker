import Foundation

protocol TreeSort {
  associatedtype KeyType: Hashable
  func cursor() throws -> KeyType
  func previousCursor() -> KeyType?
}

extension Array where Element: TreeSort {
  func treeSort() throws -> [Self] {
    let keys: [Element.KeyType] = try self.map { try $0.cursor() }
    var dict: [Element.KeyType: Element] = [:]
    var roots: Self = []
    for item in self {
      guard let prev = item.previousCursor(), keys.contains(prev), dict[prev] == nil else {
        roots.append(item)
        continue
      }
      dict[prev] = item
    }
    if roots.isEmpty {
      throw "Invalid item tree"
    }
    return try roots.map {
      var tree = [$0]
      var currentId = try $0.cursor()
      while let next = dict[currentId] {
        tree.append(next)
        currentId = try next.cursor()
      }
      return tree
    }
  }
}
