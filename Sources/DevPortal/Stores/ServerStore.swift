import AppKit
import Foundation

@MainActor
final class ServerStore: ObservableObject {
  @Published private(set) var snapshot = ServerSnapshot.empty
  @Published private(set) var isRefreshing = false
  @Published private(set) var statusMessage = "Open DevPortal to scan"
  @Published var preferences: AppPreferences
  @Published private(set) var rules: [VisibilityRule]
  @Published private(set) var history: [ServerHistoryRecord]
  @Published private(set) var launchAtLoginStatus = "Unknown"

  private let scanner = ServerScanner()
  private let processController = ProcessController()
  private let notificationService = NotificationService.shared
  private var firstSeenByID: [String: Date]
  private var staleNotificationIDs: Set<String> = []
  private var previousActiveIDs: Set<String> = []
  private var hasCompletedInitialScan = false
  private var refreshTimer: Timer?

  private enum Keys {
    static let preferences = "DevPortal.preferences"
    static let rules = "DevPortal.visibilityRules"
    static let history = "DevPortal.history"
    static let firstSeen = "DevPortal.firstSeenByID"
  }

  init() {
    preferences = PersistentStorage.load(AppPreferences.self, key: Keys.preferences, fallback: AppPreferences())
    rules = PersistentStorage.load([VisibilityRule].self, key: Keys.rules, fallback: [])
    history = PersistentStorage.load([ServerHistoryRecord].self, key: Keys.history, fallback: [])
    firstSeenByID = PersistentStorage.load([String: Date].self, key: Keys.firstSeen, fallback: [:])

    refreshLaunchAtLoginStatus()
    configureAutoRefresh()
  }

  var menuBarTitle: String {
    let count = snapshot.webAndDockerCount
    return count > 0 ? "Dev \(count)" : "Dev"
  }

  var menuBarSystemImage: String {
    snapshot.webAndDockerCount > 0 ? "terminal.fill" : "terminal"
  }

  var webServerStopSummary: String {
    snapshot.webPorts.map { "\($0.displayName) :\($0.port)" }.joined(separator: "\n")
  }

  func refreshIfNeeded() {
    guard !isRefreshing else {
      return
    }

    guard let scannedAt = snapshot.scannedAt else {
      refresh()
      return
    }

    if Date().timeIntervalSince(scannedAt) > 8 {
      refresh()
    }
  }

  func refresh() {
    guard !isRefreshing else {
      return
    }

    isRefreshing = true
    statusMessage = "Scanning local ports..."

    Task {
      let rawSnapshot = await scanner.scan()
      let nextSnapshot = process(rawSnapshot)
      snapshot = nextSnapshot
      isRefreshing = false
      statusMessage = Self.scanSummary(for: nextSnapshot)
    }
  }

  func updatePreferences(_ transform: (inout AppPreferences) -> Void) {
    transform(&preferences)
    PersistentStorage.save(preferences, key: Keys.preferences)
    configureAutoRefresh()
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    updatePreferences { $0.notificationsEnabled = enabled }

    guard enabled else {
      return
    }

    Task {
      let granted = await notificationService.requestAuthorization()
      if !granted {
        updatePreferences { $0.notificationsEnabled = false }
        statusMessage = "Notifications not allowed"
      } else {
        statusMessage = "Notifications enabled"
      }
    }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    let result = LaunchAtLoginController.setEnabled(enabled)
    launchAtLoginStatus = LaunchAtLoginController.statusText
    statusMessage = result.message
  }

  func refreshLaunchAtLoginStatus() {
    launchAtLoginStatus = LaunchAtLoginController.statusText
  }

  func open(_ server: LocalPort) {
    guard let url = server.openURL else {
      statusMessage = "No URL for :\(server.port)"
      return
    }

    NSWorkspace.shared.open(url)
    statusMessage = "Opened :\(server.port)"
  }

  func open(_ mapping: DockerPortMapping) {
    guard let url = mapping.openURL else {
      statusMessage = "No URL for :\(mapping.hostPort)"
      return
    }

    NSWorkspace.shared.open(url)
    statusMessage = "Opened :\(mapping.hostPort)"
  }

  func copyURL(_ server: LocalPort) {
    guard let url = server.openURL else {
      statusMessage = "No URL for :\(server.port)"
      return
    }

    Pasteboard.copy(url.absoluteString)
    statusMessage = "Copied URL"
  }

  func copyURL(_ mapping: DockerPortMapping) {
    guard let url = mapping.openURL else {
      statusMessage = "No URL for :\(mapping.hostPort)"
      return
    }

    Pasteboard.copy(url.absoluteString)
    statusMessage = "Copied URL"
  }

  func copyDetails(_ server: LocalPort) {
    Pasteboard.copy(server.details)
    statusMessage = "Copied details"
  }

  func copyDetails(_ container: DockerContainer) {
    Pasteboard.copy(container.details)
    statusMessage = "Copied details"
  }

  func copySnapshot() {
    var lines: [String] = []
    lines.append("DevPortal Snapshot")
    lines.append("Scanned: \(snapshot.scannedAt.map(DisplayFormat.dateTime.string) ?? "never")")

    lines.append("")
    lines.append("Web Dev Servers")
    lines.append(contentsOf: snapshot.webPorts.map {
      "- \($0.displayName) :\($0.port) \($0.runtimeDescription) PID \($0.pid) \($0.openURL?.absoluteString ?? "")"
    })

    lines.append("")
    lines.append("Docker")
    lines.append(contentsOf: snapshot.dockerContainers.map {
      "- \($0.name) \($0.image) \($0.runtimeDescription) \($0.ports.map(\.displayValue).joined(separator: ", "))"
    })

    lines.append("")
    lines.append("Other Local Ports")
    lines.append(contentsOf: snapshot.otherPorts.map {
      "- \($0.processName) :\($0.port) \($0.runtimeDescription) PID \($0.pid)"
    })

    Pasteboard.copy(lines.joined(separator: "\n"))
    statusMessage = "Copied snapshot"
  }

  func revealFolder(_ server: LocalPort) {
    guard let cwd = server.cwd else {
      statusMessage = "Folder unknown"
      return
    }

    NSWorkspace.shared.open(URL(fileURLWithPath: cwd, isDirectory: true))
    statusMessage = "Opened folder"
  }

  func openTerminal(_ server: LocalPort) {
    guard let cwd = server.cwd else {
      statusMessage = "Folder unknown"
      return
    }

    Task {
      let result = await processController.openTerminal(at: cwd)
      statusMessage = result.message
    }
  }

  func interrupt(_ server: LocalPort) {
    guard server.isOwnedByCurrentUser else {
      statusMessage = "Not your process"
      return
    }

    let result = processController.interrupt(pid: server.pid)
    statusMessage = result.message
    Task {
      try? await Task.sleep(for: .seconds(1))
      refresh()
    }
  }

  func terminate(_ server: LocalPort) {
    guard server.isOwnedByCurrentUser else {
      statusMessage = "Not your process"
      return
    }

    let result = processController.terminate(pid: server.pid)
    statusMessage = result.message
    Task {
      try? await Task.sleep(for: .seconds(1))
      refresh()
    }
  }

  func stopAllWebServers() {
    let targets = snapshot.webPorts.filter(\.isOwnedByCurrentUser)
    guard !targets.isEmpty else {
      statusMessage = "No owned web servers"
      return
    }

    for server in targets {
      _ = processController.interrupt(pid: server.pid)
    }

    statusMessage = "Stopped \(targets.count) web server\(targets.count == 1 ? "" : "s")"
    Task {
      try? await Task.sleep(for: .seconds(1))
      refresh()
    }
  }

  func stopDockerContainer(_ container: DockerContainer) {
    Task {
      statusMessage = "Stopping \(container.name)..."
      let result = await processController.stopDockerContainer(id: container.id, name: container.name)
      statusMessage = result.message
      refresh()
    }
  }

  func stopComposeProject(_ container: DockerContainer) {
    guard let project = container.composeProject else {
      statusMessage = "No compose project"
      return
    }

    Task {
      statusMessage = "Stopping \(project)..."
      let result = await processController.stopComposeProject(
        project: project,
        workingDirectory: container.composeWorkingDirectory
      )
      statusMessage = result.message
      refresh()
    }
  }

  func openDockerLogs(_ container: DockerContainer) {
    Task {
      let result = await processController.openDockerLogs(id: container.id, name: container.name)
      statusMessage = result.message
    }
  }

  func addRule(mode: VisibilityRuleMode, target: VisibilityRuleTarget, value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }

    let rule = VisibilityRule(mode: mode, target: target, value: trimmed)
    rules.insert(rule, at: 0)
    persistRules()
    refresh()
  }

  func addHideRule(for server: LocalPort, target: VisibilityRuleTarget) {
    addRule(mode: .hide, target: target, value: ruleValue(for: server, target: target))
  }

  func addAlwaysShowRule(for server: LocalPort, target: VisibilityRuleTarget) {
    addRule(mode: .alwaysShow, target: target, value: ruleValue(for: server, target: target))
  }

  func removeRule(_ rule: VisibilityRule) {
    rules.removeAll { $0.id == rule.id }
    persistRules()
    refresh()
  }

  func clearHistory() {
    history = []
    PersistentStorage.save(history, key: Keys.history)
    statusMessage = "History cleared"
  }

  private func process(_ rawSnapshot: ServerSnapshot) -> ServerSnapshot {
    let now = Date()
    let web = rawSnapshot.webPorts.map { withRuntime($0, now: now) }
    let other = rawSnapshot.otherPorts.map { withRuntime($0, now: now) }
    let docker = rawSnapshot.dockerContainers.map { withRuntime($0, now: now) }

    pruneFirstSeen(keeping: activeTrackingIDs(web: web, other: other, docker: docker))
    PersistentStorage.save(firstSeenByID, key: Keys.firstSeen)

    let visibleWeb = web.filter(isVisible)
    let visibleOther = preferences.showOtherPorts
      ? other.filter(isVisible)
      : other.filter { matchesAlwaysShowRule($0) }

    let nextSnapshot = ServerSnapshot(
      scannedAt: rawSnapshot.scannedAt,
      webPorts: visibleWeb,
      dockerContainers: docker,
      otherPorts: visibleOther,
      dockerStatus: rawSnapshot.dockerStatus
    )

    updateHistory(with: nextSnapshot, now: now)
    notifyIfNeeded(nextSnapshot, now: now)
    return nextSnapshot
  }

  private func withRuntime(_ server: LocalPort, now: Date) -> LocalPort {
    let firstSeen = firstSeenByID[server.trackingID] ?? now
    firstSeenByID[server.trackingID] = firstSeen
    return server.with(firstSeenAt: firstSeen)
  }

  private func withRuntime(_ container: DockerContainer, now: Date) -> DockerContainer {
    let firstSeen = firstSeenByID[container.trackingID] ?? now
    firstSeenByID[container.trackingID] = firstSeen
    return container.with(firstSeenAt: firstSeen)
  }

  private func pruneFirstSeen(keeping activeIDs: Set<String>) {
    firstSeenByID = firstSeenByID.filter { activeIDs.contains($0.key) }
    staleNotificationIDs = staleNotificationIDs.filter { activeIDs.contains($0) }
  }

  private func activeTrackingIDs(web: [LocalPort], other: [LocalPort], docker: [DockerContainer]) -> Set<String> {
    Set(web.map(\.trackingID) + other.map(\.trackingID) + docker.map(\.trackingID))
  }

  private func isVisible(_ server: LocalPort) -> Bool {
    if matchesAlwaysShowRule(server) {
      return true
    }

    return !rules.contains { $0.mode == .hide && $0.matches(server) }
  }

  private func matchesAlwaysShowRule(_ server: LocalPort) -> Bool {
    rules.contains { $0.mode == .alwaysShow && $0.matches(server) }
  }

  private func updateHistory(with snapshot: ServerSnapshot, now: Date) {
    var recordsByID = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0) })

    for server in snapshot.webPorts + snapshot.otherPorts {
      let firstSeen = server.firstSeenAt ?? now
      recordsByID[server.trackingID] = ServerHistoryRecord(
        id: server.trackingID,
        title: "\(server.displayName) :\(server.port)",
        kind: server.category.rawValue,
        port: server.port,
        url: server.openURL?.absoluteString,
        processName: server.processName,
        folder: server.cwd,
        firstSeenAt: recordsByID[server.trackingID]?.firstSeenAt ?? firstSeen,
        lastSeenAt: now
      )
    }

    for container in snapshot.dockerContainers {
      let firstSeen = container.firstSeenAt ?? now
      recordsByID[container.trackingID] = ServerHistoryRecord(
        id: container.trackingID,
        title: container.name,
        kind: "Docker",
        port: container.ports.first?.hostPort,
        url: container.ports.first?.openURL?.absoluteString,
        processName: "docker",
        folder: container.composeWorkingDirectory,
        firstSeenAt: recordsByID[container.trackingID]?.firstSeenAt ?? firstSeen,
        lastSeenAt: now
      )
    }

    history = Array(recordsByID.values)
      .sorted { $0.lastSeenAt > $1.lastSeenAt }
      .prefix(100)
      .map { $0 }
    PersistentStorage.save(history, key: Keys.history)
  }

  private func notifyIfNeeded(_ snapshot: ServerSnapshot, now: Date) {
    let activeIDs = snapshot.newServerNotificationTrackingIDs
    defer {
      previousActiveIDs = activeIDs
      hasCompletedInitialScan = true
    }

    guard preferences.notificationsEnabled else {
      return
    }

    if preferences.notifyNewServers, hasCompletedInitialScan {
      let newIDs = activeIDs.subtracting(previousActiveIDs)
      for server in snapshot.webPorts where newIDs.contains(server.trackingID) {
        postNotification(
          identifier: "new-\(server.trackingID)",
          title: "New dev server",
          body: "\(server.displayName) is listening on :\(server.port)"
        )
      }

      for container in snapshot.dockerContainersWithMappedPorts where newIDs.contains(container.trackingID) {
        postNotification(
          identifier: "new-\(container.trackingID)",
          title: "New Docker port",
          body: "\(container.name) exposed \(container.primaryPortLabel)"
        )
      }
    }

    guard preferences.notifyStaleServers else {
      return
    }

    let threshold = preferences.staleThresholdMinutes * 60
    for server in snapshot.webPorts {
      guard let firstSeenAt = server.firstSeenAt,
            now.timeIntervalSince(firstSeenAt) >= threshold,
            !staleNotificationIDs.contains(server.trackingID) else {
        continue
      }

      staleNotificationIDs.insert(server.trackingID)
      postNotification(
        identifier: "stale-\(server.trackingID)",
        title: "Dev server still running",
        body: "\(server.displayName) has been running \(DisplayFormat.duration(from: firstSeenAt, to: now))"
      )
    }
  }

  private func postNotification(identifier: String, title: String, body: String) {
    Task {
      await notificationService.post(
        identifier: identifier,
        title: title,
        body: body
      )
    }
  }

  private func configureAutoRefresh() {
    refreshTimer?.invalidate()
    refreshTimer = nil

    guard preferences.autoRefreshEnabled else {
      return
    }

    refreshTimer = Timer.scheduledTimer(withTimeInterval: preferences.refreshIntervalSeconds, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refresh()
      }
    }
  }

  private func persistRules() {
    PersistentStorage.save(rules, key: Keys.rules)
  }

  private func ruleValue(for server: LocalPort, target: VisibilityRuleTarget) -> String {
    switch target {
    case .process:
      return server.processName
    case .port:
      return String(server.port)
    case .folder:
      return server.cwd ?? server.source.projectPath ?? ""
    }
  }

  private static func scanSummary(for snapshot: ServerSnapshot) -> String {
    let scannedAt = snapshot.scannedAt.map(DisplayFormat.time.string) ?? "now"
    return "\(snapshot.webPorts.count) web, \(snapshot.dockerContainers.count) Docker, \(snapshot.otherPorts.count) other - \(scannedAt)"
  }
}
