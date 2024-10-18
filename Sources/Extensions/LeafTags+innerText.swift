import Leaf

extension UnsafeUnescapedLeafTag {
  func innerText(_ body: [Syntax]) -> String {
    body.compactMap { syntax in
      if case .raw(var byteBuffer) = syntax {
        byteBuffer.readString(length: byteBuffer.readableBytes)
      } else {
        nil
      }
    }
    .joined(separator: "")
  }
}
