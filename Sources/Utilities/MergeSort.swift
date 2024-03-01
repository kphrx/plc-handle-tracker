import Foundation

protocol MergeSort {
  associatedtype CompareValue: Comparable
  func compareValue() -> CompareValue
}

func mergeSort<T: MergeSort>(_ array: [T]) -> [T] {
  guard array.count > 1 else { return array }

  let middleIndex = array.count / 2
  let leftArray = mergeSort(Array(array[..<middleIndex]))
  let rightArray = mergeSort(Array(array[middleIndex...]))

  return merge(leftArray, rightArray)
}

func merge<T: MergeSort>(_ left: [T], _ right: [T]) -> [T] {
  var leftIndex = 0
  var rightIndex = 0
  var mergedArray = [T]()

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
