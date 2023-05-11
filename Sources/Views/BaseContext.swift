import Vapor

protocol BaseContext: Content {
  var title: String? { get }
  var route: String { get }
}
