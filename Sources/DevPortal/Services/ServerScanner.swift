import Foundation

final class ServerScanner: @unchecked Sendable {
  private let runner = CommandRunner()

  func scan() async -> ServerSnapshot {
    let portScanner = PortScanner(runner: runner)
    let dockerScanner = DockerScanner(runner: runner)

    let ports = await portScanner.scan()
    let dockerResult = await dockerScanner.scan()
    let localPorts = ports.filter { !$0.isDockerBridge }

    return ServerSnapshot(
      scannedAt: Date(),
      webPorts: localPorts.filter { $0.category == .webDevelopment },
      dockerContainers: dockerResult.containers,
      otherPorts: localPorts.filter { $0.category == .otherLocal },
      dockerStatus: dockerResult.status
    )
  }
}
