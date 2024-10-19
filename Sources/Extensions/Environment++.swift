import Vapor

extension Environment {
  static func get(_ key: String, _ defaultValue: String) -> String {
    Self.get(key) ?? defaultValue
  }

  static func getInt(_ key: String) -> Int? {
    Self.get(key).flatMap(Int.init(_:))
  }

  static func getInt(_ key: String, _ defaultValue: Int) -> Int {
    Self.getInt(key) ?? defaultValue
  }

  static func getUInt(_ key: String) -> UInt? {
    Self.get(key).flatMap(UInt.init(_:))
  }

  static func getUInt(_ key: String, _ defaultValue: UInt) -> UInt {
    Self.getUInt(key) ?? defaultValue
  }

  static func getBool(_ key: String, _ defaultValue: Bool = false) -> Bool {
    Self.get(key)
      .flatMap { value in
        switch value.lowercased() {
          case "true", "t", "yes", "y": true
          case "false", "f", "no", "n", "": false
          default: if let int = Int(value) { int != 0 } else { nil }
        }
      } ?? defaultValue
  }
}
