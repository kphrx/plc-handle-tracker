import Leaf

extension UnsafeUnescapedLeafTag {
  func innerText(_ body: [Syntax]) -> String {
    return body.compactMap { syntax in
      return switch syntax {
      case .raw(var byteBuffer): byteBuffer.readString(length: byteBuffer.readableBytes)
      default: nil
      }
    }.joined(separator: "")
  }
}
