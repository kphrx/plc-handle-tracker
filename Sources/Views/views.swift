import Leaf
import Vapor

func views(_ app: Application) {
  app.views.use(.leaf)
  app.leaf.tags["externalLink"] = ExternalLinkTag()
  app.leaf.tags["navLink"] = NavLinkTag()
}
