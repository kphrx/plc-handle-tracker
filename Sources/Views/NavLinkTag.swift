import Leaf

enum NavLinkTagError: Error {
  case missingHRefParameter
  case missingRouteParameter
  case missingBodyParameter
}

struct NavLinkTag: UnsafeUnescapedLeafTag {
  func render(_ ctx: LeafContext) throws -> LeafData {
    let (href, isCurrent) = try self.parameters(ctx.parameters)
    guard let body = ctx.body else {
      throw NavLinkTagError.missingBodyParameter
    }
    return LeafData.string(self.outerText(self.innerText(body), href: href, isWrap: isCurrent))
  }

  private func outerText(_ innerText: String, href: String, isWrap: Bool) -> String {
    if isWrap {
      innerText
    } else {
      "<a href=\(href)>\(innerText)</a>"
    }
  }

  private func parameters(_ parameters: [LeafData]) throws -> (String, Bool) {
    switch parameters.count {
      case 0:
        throw NavLinkTagError.missingHRefParameter
      case 1:
        throw NavLinkTagError.missingRouteParameter
      default:
        guard let href = parameters[0].string else {
          throw NavLinkTagError.missingHRefParameter
        }
        guard let route = parameters[1].string else {
          throw NavLinkTagError.missingRouteParameter
        }
        return (href, route == "GET \(href)")
    }
  }
}
