import Sparkle
import SwiftUI

struct MenuBarContentView: View {
  @EnvironmentObject private var store: ServerStore
  @Environment(\.openWindow) private var openWindow
  let updater: SPUUpdater

  var body: some View {
    Button("Open Inspector") {
      openWindow(id: "inspector")
      NSApp.activate(ignoringOtherApps: true)
    }

    Button(store.isRefreshing ? "Refreshing..." : "Refresh") {
      store.refresh()
    }
    .keyboardShortcut("r")

    Text(DisplayFormat.clipped(store.statusMessage, length: 30))

    Divider()

    CheckForUpdatesView(updater: updater)

    Divider()

    Section("Web Dev Servers") {
      if store.snapshot.webPorts.isEmpty {
        Text("None detected")
      } else {
        ForEach(store.snapshot.webPorts) { server in
          ServerMenuItemView(server: server)
        }

        Button("Stop All Web Servers") {
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
    }

    Divider()

    Section("Docker") {
      if store.snapshot.dockerContainers.isEmpty {
        Text(DisplayFormat.clipped(store.snapshot.dockerStatus.message ?? "No containers", length: 30))
      } else {
        ForEach(store.snapshot.dockerContainers) { container in
          DockerMenuItemView(container: container)
        }
      }
    }

    Divider()

    Section("Other Local Ports") {
      if store.snapshot.otherPorts.isEmpty {
        Text("None detected")
      } else {
        ForEach(store.snapshot.otherPorts) { server in
          ServerMenuItemView(server: server)
        }
      }
    }

    Divider()

    Button("Copy Snapshot") {
      store.copySnapshot()
    }

    Menu("Settings") {
      Toggle("Auto Refresh", isOn: Binding(
        get: { store.preferences.autoRefreshEnabled },
        set: { value in store.updatePreferences { $0.autoRefreshEnabled = value } }
      ))

      Toggle("Show Other Ports", isOn: Binding(
        get: { store.preferences.showOtherPorts },
        set: { value in store.updatePreferences { $0.showOtherPorts = value } }
      ))

      Toggle("Notifications", isOn: Binding(
        get: { store.preferences.notificationsEnabled },
        set: { value in store.setNotificationsEnabled(value) }
      ))

      Toggle("Launch At Login", isOn: Binding(
        get: { LaunchAtLoginController.isEnabled },
        set: { value in store.setLaunchAtLogin(value) }
      ))

      Text(DisplayFormat.clipped("Login: \(store.launchAtLoginStatus)", length: 30))
    }

    Button("Quit DevPortal") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
