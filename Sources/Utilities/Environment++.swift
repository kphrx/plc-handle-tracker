import Vapor

extension Environment {
  static func getBool(_ key: String, _ defaultValue: Bool = false) -> Bool {
    Self.get(key).flatMap({
      switch $0.lowercased() {
      case "true", "t", "yes", "y":
        return true
      case "false", "f", "no", "n", "":
        return false
      default:
        if let int = Int($0) {
          return int != 0
        }
        return nil
      }
    }) ?? defaultValue
  }
}
