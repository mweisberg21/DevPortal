import Foundation

struct DockerContainer: Identifiable, Hashable {
  let id: String
  let name: String
  let image: String
  let command: String
  let status: String
  let ports: [DockerPortMapping]
  let composeProject: String?
  let composeService: String?
  let composeWorkingDirectory: String?
  let composeConfigFiles: String?
  let firstSeenAt: Date?

  var menuTitle: String {
    DisplayFormat.clipped("\(name) \(primaryPortLabel)", length: 30)
  }

  var trackingID: String {
    ["docker", composeProject ?? "", name, id].joined(separator: "|")
  }

  var composeGroupTitle: String {
    guard let composeProject, !composeProject.isEmpty else {
      return "Standalone Containers"
    }

    return composeProject
  }

  var runtimeDescription: String {
    guard let firstSeenAt else {
      return "Runtime unknown"
    }

    return "Running \(DisplayFormat.duration(from: firstSeenAt, to: Date()))"
  }

  var primaryPortLabel: String {
    guard let firstPort = ports.first else {
      return ""
    }

    return ":\(firstPort.hostPort)"
  }

  var details: String {
    [
      "Container: \(name)",
      "ID: \(id)",
      "Image: \(image)",
      "Command: \(command)",
      "Status: \(status)",
      "Runtime: \(runtimeDescription)",
      "Compose project: \(composeProject ?? "none")",
      "Compose service: \(composeService ?? "none")",
      "Compose directory: \(composeWorkingDirectory ?? "unknown")",
      "Ports: \(ports.map(\.displayValue).joined(separator: ", "))"
    ].joined(separator: "\n")
  }

  func with(firstSeenAt: Date?) -> DockerContainer {
    DockerContainer(
      id: id,
      name: name,
      image: image,
      command: command,
      status: status,
      ports: ports,
      composeProject: composeProject,
      composeService: composeService,
      composeWorkingDirectory: composeWorkingDirectory,
      composeConfigFiles: composeConfigFiles,
      firstSeenAt: firstSeenAt
    )
  }

  func matchesSearch(_ query: String) -> Bool {
    guard !query.isEmpty else {
      return true
    }

    return [
      name,
      image,
      status,
      composeProject ?? "",
      composeService ?? ""
    ].joined(separator: " ").localizedCaseInsensitiveContains(query)
  }
}

struct DockerPortMapping: Identifiable, Hashable {
  let host: String
  let hostPort: Int
  let containerPort: Int?
  let proto: String

  var id: String {
    "\(host)-\(hostPort)-\(containerPort ?? 0)-\(proto)"
  }

  var displayValue: String {
    if let containerPort {
      return "\(host):\(hostPort)->\(containerPort)/\(proto)"
    }

    return "\(host):\(hostPort)/\(proto)"
  }

  var openURL: URL? {
    let scheme = DisplayFormat.scheme(for: hostPort)
    let urlHost = DisplayFormat.urlHost(for: host)
    return URL(string: "\(scheme)://\(urlHost):\(hostPort)")
  }
}

enum DockerStatus: Equatable {
  case available
  case unavailable(String)
  case error(String)

  var message: String? {
    switch self {
    case .available:
      nil
    case .unavailable(let message), .error(let message):
      message
    }
  }
}

struct DockerScanResult: Equatable {
  let status: DockerStatus
  let containers: [DockerContainer]
}
