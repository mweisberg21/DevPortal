import Foundation

final class DockerScanner: @unchecked Sendable {
  private let runner: CommandRunner

  init(runner: CommandRunner) {
    self.runner = runner
  }

  func scan() async -> DockerScanResult {
    guard let docker = Self.dockerExecutablePath() else {
      return DockerScanResult(
        status: .unavailable("Docker CLI not found"),
        containers: []
      )
    }

    let result = await runner.run(
      docker,
      arguments: ["ps", "--format", "{{json .}}"],
      timeout: 4
    )

    if result.timedOut {
      return DockerScanResult(
        status: .error("Docker scan timed out"),
        containers: []
      )
    }

    guard result.succeeded else {
      let message = result.trimmedStderr.isEmpty ? "Docker is not running" : result.trimmedStderr
      return DockerScanResult(
        status: .unavailable(DisplayFormat.clipped(message, length: 80)),
        containers: []
      )
    }

    let containers = parseDockerRows(result.stdout)
    return DockerScanResult(status: .available, containers: containers)
  }

  static func dockerExecutablePath() -> String? {
    let candidates = [
      "/usr/local/bin/docker",
      "/opt/homebrew/bin/docker",
      "/usr/bin/docker"
    ]

    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
  }

  private func parseDockerRows(_ output: String) -> [DockerContainer] {
    DockerPortParser.parseContainers(output)
  }
}
