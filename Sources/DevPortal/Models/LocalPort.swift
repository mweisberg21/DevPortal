import Foundation

enum LocalPortCategory: String {
  case webDevelopment = "Web Dev Servers"
  case otherLocal = "Other Local Ports"
}

struct LocalPort: Identifiable, Hashable {
  let pid: Int32
  let parentPID: Int32?
  let processName: String
  let command: String
  let cwd: String?
  let host: String
  let port: Int
  let userID: UInt32?
  let category: LocalPortCategory
  let isOwnedByCurrentUser: Bool
  let isDockerBridge: Bool
  let source: SourceSummary
  let firstSeenAt: Date?

  var id: String {
    "\(pid)-\(host)-\(port)"
  }

  var trackingID: String {
    [
      "local",
      source.projectPath ?? cwd ?? processName,
      processName,
      String(port)
    ].joined(separator: "|")
  }

  var openURL: URL? {
    let scheme = DisplayFormat.scheme(for: port)
    let urlHost = DisplayFormat.urlHost(for: host)
    return URL(string: "\(scheme)://\(urlHost):\(port)")
  }

  var menuTitle: String {
    DisplayFormat.clipped("\(displayName) :\(port)", length: 30)
  }

  var sourceName: String {
    if let cwd, let last = cwd.split(separator: "/").last, !last.isEmpty {
      return String(last)
    }

    return processName
  }

  var displayName: String {
    source.displayName.isEmpty ? sourceName : source.displayName
  }

  var pathSummary: String {
    guard let cwd else {
      return "Folder unknown"
    }

    return DisplayFormat.compactPath(cwd, maxLength: 30)
  }

  var processSummary: String {
    "PID \(pid) - \(processName)"
  }

  var runtimeDescription: String {
    guard let firstSeenAt else {
      return "Runtime unknown"
    }

    return "Running \(DisplayFormat.duration(from: firstSeenAt, to: Date()))"
  }

  var details: String {
    var lines = [
      "Name: \(displayName)",
      "Process: \(processName)",
      "PID: \(pid)",
      "Parent PID: \(parentPID.map(String.init) ?? "unknown")",
      "Host: \(host)",
      "Port: \(port)",
      "URL: \(openURL?.absoluteString ?? "unknown")",
      "Runtime: \(runtimeDescription)",
      "Folder: \(cwd ?? "unknown")",
      "Git branch: \(source.gitBranch ?? "unknown")",
      "Package script: \(source.packageScript ?? "unknown")",
      "Command type: \(source.commandKind ?? "unknown")",
      "Command: \(command)"
    ]

    if let userID {
      lines.insert("UID: \(userID)", at: 3)
    }

    return lines.joined(separator: "\n")
  }

  func with(firstSeenAt: Date?) -> LocalPort {
    LocalPort(
      pid: pid,
      parentPID: parentPID,
      processName: processName,
      command: command,
      cwd: cwd,
      host: host,
      port: port,
      userID: userID,
      category: category,
      isOwnedByCurrentUser: isOwnedByCurrentUser,
      isDockerBridge: isDockerBridge,
      source: source,
      firstSeenAt: firstSeenAt
    )
  }

  func matchesSearch(_ query: String) -> Bool {
    guard !query.isEmpty else {
      return true
    }

    return [
      displayName,
      processName,
      command,
      cwd ?? "",
      String(port),
      source.gitBranch ?? "",
      source.commandKind ?? ""
    ].joined(separator: " ").localizedCaseInsensitiveContains(query)
  }
}

struct ServerSnapshot: Equatable {
  let scannedAt: Date?
  let webPorts: [LocalPort]
  let dockerContainers: [DockerContainer]
  let otherPorts: [LocalPort]
  let dockerStatus: DockerStatus

  static let empty = ServerSnapshot(
    scannedAt: nil,
    webPorts: [],
    dockerContainers: [],
    otherPorts: [],
    dockerStatus: .unavailable("Not scanned yet")
  )

  var localPorts: [LocalPort] {
    webPorts + otherPorts
  }

  var webAndDockerCount: Int {
    webPorts.count + dockerContainers.count
  }

  var dockerContainersWithMappedPorts: [DockerContainer] {
    dockerContainers.filter { !$0.ports.isEmpty }
  }

  var newServerNotificationTrackingIDs: Set<String> {
    Set(webPorts.map(\.trackingID) + dockerContainersWithMappedPorts.map(\.trackingID))
  }
}
