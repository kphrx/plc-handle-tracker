import Leaf

extension UnsafeUnescapedLeafTag {
  func innerText(_ body: [Syntax]) -> String {
    return body.compactMap {
      switch $0 {
      case .raw(var byteBuffer): byteBuffer.readString(length: byteBuffer.readableBytes)
      default: nil
      }
    }.joined(separator: "")
  }
}
