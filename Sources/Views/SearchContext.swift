import Vapor

protocol SearchContext: BaseContext {
  var count: Int { get }
  var currentValue: String? { get }
  var message: String? { get }
}
