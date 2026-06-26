import SwiftUI

struct DockerMenuItemView: View {
  @EnvironmentObject private var store: ServerStore
  let container: DockerContainer

  var body: some View {
    Menu(container.menuTitle) {
      if container.ports.isEmpty {
        Text("No mapped ports")
      } else {
        ForEach(container.ports) { port in
          Button("Open :\(port.hostPort)") {
            store.open(port)
          }

          Button("Copy URL :\(port.hostPort)") {
            store.copyURL(port)
          }
        }
      }

      Divider()
      Text(DisplayFormat.clipped(container.image, length: 30))
      Text(DisplayFormat.clipped(container.status, length: 30))
      Text(DisplayFormat.clipped(container.runtimeDescription, length: 30))
      if let composeProject = container.composeProject {
        Text(DisplayFormat.clipped("Compose \(composeProject)", length: 30))
      }
      Button("Copy Details") {
        store.copyDetails(container)
      }

      Divider()
      Button("Open Logs") {
        store.openDockerLogs(container)
      }

      if container.composeProject != nil {
        Button("Stop Compose Project") {
          let confirmed = Confirmations.confirmDestructive(
            title: "Stop compose project?",
            message: container.composeProject ?? container.name,
            actionTitle: "Stop Project"
          )

          if confirmed {
            store.stopComposeProject(container)
          }
        }
      }

      Button("Stop Container") {
        store.stopDockerContainer(container)
      }
    }
  }
}
