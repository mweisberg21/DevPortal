import Foundation

enum DisplayFormat {
  static let time: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
  }()

  static let dateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    formatter.dateStyle = .short
    return formatter
  }()

  static func clipped(_ value: String, length: Int) -> String {
    guard value.count > length else {
      return value
    }

    guard length > 3 else {
      return String(value.prefix(length))
    }

    return String(value.prefix(length - 3)) + "..."
  }

  static func compactPath(_ path: String, maxLength: Int) -> String {
    guard path.count > maxLength else {
      return path
    }

    let components = path.split(separator: "/").map(String.init)
    guard let last = components.last else {
      return clipped(path, length: maxLength)
    }

    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path.hasPrefix(home) {
      return clipped("~/.../\(last)", length: maxLength)
    }

    return clipped(".../\(last)", length: maxLength)
  }

  static func duration(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start)))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60

    if hours > 0 {
      return "\(hours)h \(minutes)m"
    }

    if minutes > 0 {
      return "\(minutes)m"
    }

    return "\(seconds)s"
  }

  static func scheme(for port: Int) -> String {
    switch port {
    case 443, 8443:
      return "https"
    default:
      return "http"
    }
  }

  static func urlHost(for host: String) -> String {
    switch host {
    case "*", "0.0.0.0", "::", "::1", "127.0.0.1", "localhost":
      return "localhost"
    default:
      if host.contains(":") {
        return "[\(host)]"
      }

      return host
    }
  }
}
