import Foundation

struct AppPreferences: Codable, Equatable {
  var autoRefreshEnabled = true
  var refreshIntervalSeconds = 60.0
  var notificationsEnabled = false
  var notifyNewServers = true
  var notifyStaleServers = true
  var staleThresholdMinutes = 60.0
  var showOtherPorts = true
}

enum VisibilityRuleMode: String, Codable, CaseIterable, Identifiable {
  case hide
  case alwaysShow

  var id: String { rawValue }

  var label: String {
    switch self {
    case .hide:
      return "Hide"
    case .alwaysShow:
      return "Always Show"
    }
  }
}

enum VisibilityRuleTarget: String, Codable, CaseIterable, Identifiable {
  case process
  case port
  case folder

  var id: String { rawValue }

  var label: String {
    switch self {
    case .process:
      return "Process"
    case .port:
      return "Port"
    case .folder:
      return "Folder"
    }
  }
}

struct VisibilityRule: Codable, Identifiable, Hashable {
  var id = UUID()
  var mode: VisibilityRuleMode
  var target: VisibilityRuleTarget
  var value: String
  var createdAt = Date()

  var label: String {
    "\(mode.label) \(target.label): \(value)"
  }

  func matches(_ server: LocalPort) -> Bool {
    let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalizedValue.isEmpty else {
      return false
    }

    switch target {
    case .process:
      return server.processName.lowercased().contains(normalizedValue)
        || server.command.lowercased().contains(normalizedValue)
    case .port:
      return String(server.port) == normalizedValue
    case .folder:
      return (server.cwd ?? "").lowercased().contains(normalizedValue)
    }
  }
}

struct ServerHistoryRecord: Codable, Identifiable, Hashable {
  let id: String
  var title: String
  var kind: String
  var port: Int?
  var url: String?
  var processName: String
  var folder: String?
  var firstSeenAt: Date
  var lastSeenAt: Date

  var lastSeenDescription: String {
    DisplayFormat.dateTime.string(from: lastSeenAt)
  }

  func matchesSearch(_ query: String) -> Bool {
    guard !query.isEmpty else {
      return true
    }

    return [
      title,
      kind,
      processName,
      folder ?? "",
      url ?? ""
    ].joined(separator: " ").localizedCaseInsensitiveContains(query)
  }
}

struct SourceSummary: Hashable, Codable {
  var displayName: String
  var projectName: String?
  var projectPath: String?
  var gitBranch: String?
  var packageScript: String?
  var packageManager: String?
  var commandKind: String?

  static let unknown = SourceSummary(
    displayName: "",
    projectName: nil,
    projectPath: nil,
    gitBranch: nil,
    packageScript: nil,
    packageManager: nil,
    commandKind: nil
  )
}
