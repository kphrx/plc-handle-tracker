import Leaf

extension UnsafeUnescapedLeafTag {
  func innerText(_ body: [Syntax]) -> String {
    return body.compactMap { syntax in
      switch syntax {
      case .raw(var byteBuffer): return byteBuffer.readString(length: byteBuffer.readableBytes)
      default: return nil
      }
    }.joined(separator: "")
  }
}
