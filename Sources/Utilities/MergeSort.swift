import Foundation

protocol MergeSort {
  associatedtype CompareValue: Comparable
  func compareValue() -> CompareValue
}

extension Array where Element: MergeSort {
  func mergeSort() -> Self {
    guard self.count > 1 else { return self }

    let middleIndex = self.count / 2
    let leftArray = Array(self[..<middleIndex]).mergeSort()
    let rightArray = Array(self[middleIndex...]).mergeSort()

    return Self.merge(leftArray, rightArray)
  }

  static func merge(_ left: Self, _ right: Self) -> Self {
    var leftIndex = 0
    var rightIndex = 0
    var mergedArray = Self()

    while leftIndex < left.count && rightIndex < right.count {
      if left[leftIndex].compareValue() < right[rightIndex].compareValue() {
        mergedArray.append(left[leftIndex])
        leftIndex += 1
      } else {
        mergedArray.append(right[rightIndex])
        rightIndex += 1
      }
    }

    mergedArray += Array(left[leftIndex...])
    mergedArray += Array(right[rightIndex...])

    return mergedArray
  }
}
