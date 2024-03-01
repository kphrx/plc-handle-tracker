import Leaf
import Vapor

func registerViews(_ app: Application) {
  app.views.use(.leaf)
  app.leaf.tags["externalLink"] = ExternalLinkTag()
  app.leaf.tags["navLink"] = NavLinkTag()
}
