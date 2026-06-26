import SwiftUI

struct ServerMenuItemView: View {
  @EnvironmentObject private var store: ServerStore
  let server: LocalPort

  var body: some View {
    Menu(server.menuTitle) {
      Button("Open :\(server.port)") {
        store.open(server)
      }

      Button("Copy URL") {
        store.copyURL(server)
      }

      Divider()

      Text(DisplayFormat.clipped(server.processSummary, length: 30))
      Text(DisplayFormat.clipped(server.runtimeDescription, length: 30))
      if let branch = server.source.gitBranch {
        Text(DisplayFormat.clipped("Branch \(branch)", length: 30))
      }
      Text(server.pathSummary)

      Button("Reveal Folder") {
        store.revealFolder(server)
      }
      .disabled(server.cwd == nil)

      Button("Open Terminal Here") {
        store.openTerminal(server)
      }
      .disabled(server.cwd == nil)

      Button("Copy Details") {
        store.copyDetails(server)
      }

      Menu("Rules") {
        Button("Hide Process") {
          store.addHideRule(for: server, target: .process)
        }

        Button("Hide Port") {
          store.addHideRule(for: server, target: .port)
        }

        Button("Hide Folder") {
          store.addHideRule(for: server, target: .folder)
        }

        Divider()

        Button("Always Show Process") {
          store.addAlwaysShowRule(for: server, target: .process)
        }

        Button("Always Show Port") {
          store.addAlwaysShowRule(for: server, target: .port)
        }
      }

      Divider()

      if server.isOwnedByCurrentUser {
        Button("Stop Gracefully") {
          if server.category == .webDevelopment {
            store.interrupt(server)
          } else {
            let confirmed = Confirmations.confirmDestructive(
              title: "Stop \(server.processName)?",
              message: "This sends SIGINT to PID \(server.pid). This item is in Other Local Ports, so confirm it is not a system or app helper before stopping it.",
              actionTitle: "Stop"
            )

            if confirmed {
              store.interrupt(server)
            }
          }
        }

        Button("Terminate") {
          let confirmed = Confirmations.confirmDestructive(
            title: "Terminate \(server.processName)?",
            message: "This sends SIGTERM to PID \(server.pid). Use it only if graceful stop did not work.",
            actionTitle: "Terminate"
          )

          if confirmed {
            store.terminate(server)
          }
        }
      } else {
        Text("Stop unavailable")
      }
    }
  }
}
