import Leaf

enum ExternalLinkTagError: Error {
  case missingHRefParameter
}

struct ExternalLinkTag: UnsafeUnescapedLeafTag {
  func render(_ ctx: LeafContext) throws -> LeafData {
    let (href, text) = try self.parameters(ctx.parameters)
    if let body = ctx.body {
      return LeafData.string(
        "<a rel=noopener target=_blank href=\(href)>\(text) \(self.innerText(body))</a>")
    }
    return LeafData.string("<a rel=noopener target=_blank href=\(href)>\(text)</a>")
  }

  private func parameters(_ parameters: [LeafData]) throws -> (String, String) {
    switch parameters.count {
    case 0:
      throw ExternalLinkTagError.missingHRefParameter
    case 1:
      guard let href = parameters[0].string else {
        throw ExternalLinkTagError.missingHRefParameter
      }
      return (href, href)
    default:
      guard let href = parameters[0].string else {
        throw ExternalLinkTagError.missingHRefParameter
      }
      return (href, parameters[1].string ?? href)
    }
  }
}
