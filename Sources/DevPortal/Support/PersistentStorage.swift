import Foundation

@MainActor
enum PersistentStorage {
  static func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
    let defaults = UserDefaults.standard
    guard let data = defaults.data(forKey: key),
          let decoded = try? JSONDecoder().decode(type, from: data) else {
      return fallback
    }

    return decoded
  }

  static func save<T: Encodable>(_ value: T, key: String) {
    let defaults = UserDefaults.standard
    guard let data = try? JSONEncoder().encode(value) else {
      return
    }

    defaults.set(data, forKey: key)
  }
}
