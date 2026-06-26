import Foundation

struct RawListener: Equatable, Sendable {
  let pid: Int32
  let processName: String
  let userID: UInt32?
  let host: String
  let port: Int
}

enum LsofParser {
  static func parseListeners(_ output: String) -> [RawListener] {
    var currentPID: Int32?
    var currentCommand = ""
    var currentUID: UInt32?
    var listeners: [RawListener] = []
    var seen: Set<String> = []

    for line in output.split(separator: "\n").map(String.init) {
      guard let field = line.first else {
        continue
      }

      let value = String(line.dropFirst())
      switch field {
      case "p":
        currentPID = Int32(value)
        currentCommand = ""
        currentUID = nil
      case "c":
        currentCommand = value
      case "u":
        currentUID = UInt32(value)
      case "n":
        guard let currentPID,
              let hostPort = parseHostPort(value) else {
          continue
        }

        let key = "\(currentPID)-\(hostPort.host)-\(hostPort.port)"
        guard !seen.contains(key) else {
          continue
        }

        seen.insert(key)
        listeners.append(
          RawListener(
            pid: currentPID,
            processName: currentCommand.isEmpty ? "unknown" : currentCommand,
            userID: currentUID,
            host: hostPort.host,
            port: hostPort.port
          )
        )
      default:
        continue
      }
    }

    return listeners
  }

  static func parseHostPort(_ value: String) -> (host: String, port: Int)? {
    let cleaned = value
      .replacingOccurrences(of: " (LISTEN)", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if cleaned.hasPrefix("["),
       let bracket = cleaned.firstIndex(of: "]"),
       bracket < cleaned.endIndex,
       let colon = cleaned[cleaned.index(after: bracket)...].firstIndex(of: ":"),
       let port = Int(cleaned[cleaned.index(after: colon)...]) {
      let host = cleaned[cleaned.index(after: cleaned.startIndex)..<bracket]
      return (String(host), port)
    }

    guard let colon = cleaned.lastIndex(of: ":"),
          let port = Int(cleaned[cleaned.index(after: colon)...]) else {
      return nil
    }

    let host = String(cleaned[..<colon])
    return (host.isEmpty ? "*" : host, port)
  }
}
