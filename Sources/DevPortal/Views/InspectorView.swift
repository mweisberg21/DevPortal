import SwiftUI

private enum InspectorTab: String, CaseIterable, Identifiable {
  case servers = "Servers"
  case history = "History"
  case rules = "Rules"
  case settings = "Settings"

  var id: String { rawValue }
}

struct InspectorView: View {
  @EnvironmentObject private var store: ServerStore
  @State private var selectedTab: InspectorTab = .servers
  @State private var searchText = ""
  @State private var selectedID: String?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("View", selection: $selectedTab) {
          ForEach(InspectorTab.allCases) { tab in
            Text(tab.rawValue).tag(tab)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 360)

        Spacer()

        Button("Refresh") {
          store.refresh()
        }

        Button("Stop All Web") {
          confirmStopAllWeb()
        }
        .disabled(store.snapshot.webPorts.isEmpty)
      }
      .padding(12)

      Divider()

      switch selectedTab {
      case .servers:
        ServerInspectorView(searchText: $searchText, selectedID: $selectedID)
      case .history:
        HistoryInspectorView(searchText: $searchText)
      case .rules:
        RulesInspectorView()
      case .settings:
        SettingsInspectorView()
      }
    }
  }

  private func confirmStopAllWeb() {
    let confirmed = Confirmations.confirmDestructive(
      title: "Stop all web servers?",
      message: store.webServerStopSummary,
      actionTitle: "Stop All"
    )

    if confirmed {
      store.stopAllWebServers()
    }
  }
}

private struct ServerInspectorView: View {
  @EnvironmentObject private var store: ServerStore
  @Binding var searchText: String
  @Binding var selectedID: String?

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedID) {
        Section("Web Dev Servers") {
          ForEach(filtered(store.snapshot.webPorts)) { server in
            LocalPortRow(server: server)
              .tag("local:\(server.trackingID)")
          }
        }

        Section("Docker") {
          ForEach(filtered(store.snapshot.dockerContainers)) { container in
            DockerContainerRow(container: container)
              .tag("docker:\(container.trackingID)")
          }
        }

        Section("Other Local Ports") {
          ForEach(filtered(store.snapshot.otherPorts)) { server in
            LocalPortRow(server: server)
              .tag("local:\(server.trackingID)")
          }
        }
      }
      .searchable(text: $searchText)
      .navigationTitle("DevPortal")
    } detail: {
      DetailSelectionView(selectionID: selectedID)
    }
  }

  private func filtered(_ servers: [LocalPort]) -> [LocalPort] {
    servers.filter { $0.matchesSearch(searchText) }
  }

  private func filtered(_ containers: [DockerContainer]) -> [DockerContainer] {
    containers.filter { $0.matchesSearch(searchText) }
  }
}

private struct LocalPortRow: View {
  let server: LocalPort

  var body: some View {
    HStack {
      Image(systemName: server.category == .webDevelopment ? "globe" : "network")
      VStack(alignment: .leading, spacing: 2) {
        Text("\(server.displayName) :\(server.port)")
          .lineLimit(1)
        Text("\(server.runtimeDescription) - PID \(server.pid)")
          .foregroundStyle(.secondary)
          .font(.caption)
          .lineLimit(1)
      }
    }
  }
}

private struct DockerContainerRow: View {
  let container: DockerContainer

  var body: some View {
    HStack {
      Image(systemName: "shippingbox")
      VStack(alignment: .leading, spacing: 2) {
        Text(container.name)
          .lineLimit(1)
        Text("\(container.composeGroupTitle) - \(container.runtimeDescription)")
          .foregroundStyle(.secondary)
          .font(.caption)
          .lineLimit(1)
      }
    }
  }
}

private struct DetailSelectionView: View {
  @EnvironmentObject private var store: ServerStore
  let selectionID: String?

  var body: some View {
    if let server = selectedLocalPort {
      LocalPortDetailView(server: server)
    } else if let container = selectedDockerContainer {
      DockerDetailView(container: container)
    } else {
      ContentUnavailableView("Select an item", systemImage: "sidebar.left")
    }
  }

  private var selectedLocalPort: LocalPort? {
    guard let selectionID, selectionID.hasPrefix("local:") else {
      return nil
    }

    let id = String(selectionID.dropFirst("local:".count))
    return store.snapshot.localPorts.first { $0.trackingID == id }
  }

  private var selectedDockerContainer: DockerContainer? {
    guard let selectionID, selectionID.hasPrefix("docker:") else {
      return nil
    }

    let id = String(selectionID.dropFirst("docker:".count))
    return store.snapshot.dockerContainers.first { $0.trackingID == id }
  }
}

private struct LocalPortDetailView: View {
  @EnvironmentObject private var store: ServerStore
  let server: LocalPort

  var body: some View {
    Form {
      Section("Server") {
        LabeledContent("Name", value: server.displayName)
        LabeledContent("URL", value: server.openURL?.absoluteString ?? "unknown")
        LabeledContent("Runtime", value: server.runtimeDescription)
        LabeledContent("Category", value: server.category.rawValue)
      }

      Section("Source") {
        LabeledContent("Folder", value: server.cwd ?? "unknown")
        LabeledContent("Git Branch", value: server.source.gitBranch ?? "unknown")
        LabeledContent("Package Script", value: server.source.packageScript ?? "unknown")
        LabeledContent("Command Type", value: server.source.commandKind ?? "unknown")
      }

      Section("Process") {
        LabeledContent("Process", value: server.processName)
        LabeledContent("PID", value: String(server.pid))
        LabeledContent("Command", value: server.command)
      }

      Section("Actions") {
        HStack {
          Button("Open") { store.open(server) }
          Button("Copy URL") { store.copyURL(server) }
          Button("Reveal Folder") { store.revealFolder(server) }
            .disabled(server.cwd == nil)
          Button("Terminal") { store.openTerminal(server) }
            .disabled(server.cwd == nil)
        }

        HStack {
          Button("Stop Gracefully") { store.interrupt(server) }
            .disabled(!server.isOwnedByCurrentUser)
          Button("Terminate") {
            let confirmed = Confirmations.confirmDestructive(
              title: "Terminate \(server.processName)?",
              message: "This sends SIGTERM to PID \(server.pid).",
              actionTitle: "Terminate"
            )
            if confirmed { store.terminate(server) }
          }
          .disabled(!server.isOwnedByCurrentUser)
        }

        HStack {
          Button("Hide Process") { store.addHideRule(for: server, target: .process) }
          Button("Hide Port") { store.addHideRule(for: server, target: .port) }
          Button("Always Show") { store.addAlwaysShowRule(for: server, target: .process) }
        }
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}

private struct DockerDetailView: View {
  @EnvironmentObject private var store: ServerStore
  let container: DockerContainer

  var body: some View {
    Form {
      Section("Container") {
        LabeledContent("Name", value: container.name)
        LabeledContent("Image", value: container.image)
        LabeledContent("Status", value: container.status)
        LabeledContent("Runtime", value: container.runtimeDescription)
      }

      Section("Compose") {
        LabeledContent("Project", value: container.composeProject ?? "none")
        LabeledContent("Service", value: container.composeService ?? "none")
        LabeledContent("Folder", value: container.composeWorkingDirectory ?? "unknown")
      }

      Section("Ports") {
        ForEach(container.ports) { port in
          HStack {
            Text(port.displayValue)
            Spacer()
            Button("Open") { store.open(port) }
            Button("Copy URL") { store.copyURL(port) }
          }
        }
      }

      Section("Actions") {
        HStack {
          Button("Open Logs") { store.openDockerLogs(container) }
          Button("Copy Details") { store.copyDetails(container) }
          Button("Stop Container") { store.stopDockerContainer(container) }
          Button("Stop Compose") { store.stopComposeProject(container) }
            .disabled(container.composeProject == nil)
        }
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}

private struct HistoryInspectorView: View {
  @EnvironmentObject private var store: ServerStore
  @Binding var searchText: String

  var body: some View {
    VStack(spacing: 0) {
      List(filteredHistory) { record in
        VStack(alignment: .leading, spacing: 3) {
          Text(record.title)
          Text("\(record.kind) - Last seen \(record.lastSeenDescription)")
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      }
      .searchable(text: $searchText)

      Divider()

      HStack {
        Spacer()
        Button("Clear History") {
          store.clearHistory()
        }
      }
      .padding(12)
    }
  }

  private var filteredHistory: [ServerHistoryRecord] {
    store.history.filter { $0.matchesSearch(searchText) }
  }
}

private struct RulesInspectorView: View {
  @EnvironmentObject private var store: ServerStore
  @State private var mode: VisibilityRuleMode = .hide
  @State private var target: VisibilityRuleTarget = .process
  @State private var value = ""

  var body: some View {
    Form {
      Section("Add Rule") {
        Picker("Mode", selection: $mode) {
          ForEach(VisibilityRuleMode.allCases) { mode in
            Text(mode.label).tag(mode)
          }
        }

        Picker("Target", selection: $target) {
          ForEach(VisibilityRuleTarget.allCases) { target in
            Text(target.label).tag(target)
          }
        }

        TextField("Value", text: $value)

        Button("Add Rule") {
          store.addRule(mode: mode, target: target, value: value)
          value = ""
        }
      }

      Section("Rules") {
        if store.rules.isEmpty {
          Text("No rules")
        } else {
          ForEach(store.rules) { rule in
            HStack {
              Text(rule.label)
              Spacer()
              Button("Remove") {
                store.removeRule(rule)
              }
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}

private struct SettingsInspectorView: View {
  @EnvironmentObject private var store: ServerStore

  var body: some View {
    Form {
      Section("General") {
        Toggle("Auto Refresh", isOn: Binding(
          get: { store.preferences.autoRefreshEnabled },
          set: { value in store.updatePreferences { $0.autoRefreshEnabled = value } }
        ))

        Stepper(
          "Refresh every \(Int(store.preferences.refreshIntervalSeconds))s",
          value: Binding(
            get: { store.preferences.refreshIntervalSeconds },
            set: { value in store.updatePreferences { $0.refreshIntervalSeconds = value } }
          ),
          in: 15...300,
          step: 15
        )

        Toggle("Show Other Local Ports", isOn: Binding(
          get: { store.preferences.showOtherPorts },
          set: { value in store.updatePreferences { $0.showOtherPorts = value } }
        ))
      }

      Section("Notifications") {
        Toggle("Enable Notifications", isOn: Binding(
          get: { store.preferences.notificationsEnabled },
          set: { value in store.setNotificationsEnabled(value) }
        ))

        Toggle("New Servers", isOn: Binding(
          get: { store.preferences.notifyNewServers },
          set: { value in store.updatePreferences { $0.notifyNewServers = value } }
        ))

        Toggle("Long Running Servers", isOn: Binding(
          get: { store.preferences.notifyStaleServers },
          set: { value in store.updatePreferences { $0.notifyStaleServers = value } }
        ))

        Stepper(
          "Long-running threshold \(Int(store.preferences.staleThresholdMinutes))m",
          value: Binding(
            get: { store.preferences.staleThresholdMinutes },
            set: { value in store.updatePreferences { $0.staleThresholdMinutes = value } }
          ),
          in: 5...480,
          step: 5
        )
      }

      Section("Startup") {
        Toggle("Launch At Login", isOn: Binding(
          get: { LaunchAtLoginController.isEnabled },
          set: { value in store.setLaunchAtLogin(value) }
        ))

        LabeledContent("Status", value: store.launchAtLoginStatus)

        Button("Refresh Status") {
          store.refreshLaunchAtLoginStatus()
        }
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}
