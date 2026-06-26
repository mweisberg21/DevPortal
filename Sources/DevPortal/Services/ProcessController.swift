import AppKit
import Darwin
import Foundation

struct ProcessActionResult: Equatable, Sendable {
  let succeeded: Bool
  let message: String
}

final class ProcessController: @unchecked Sendable {
  private let runner = CommandRunner()

  func interrupt(pid: Int32) -> ProcessActionResult {
    send(signal: SIGINT, to: pid, successMessage: "Sent SIGINT to PID \(pid)")
  }

  func terminate(pid: Int32) -> ProcessActionResult {
    send(signal: SIGTERM, to: pid, successMessage: "Sent SIGTERM to PID \(pid)")
  }

  func stopDockerContainer(id: String, name: String) async -> ProcessActionResult {
    guard let docker = dockerExecutablePath() else { return dockerNotFound }

    let result = await runner.run(docker, arguments: ["stop", id], timeout: 12)
    return actionResult(
      result,
      successMessage: "Stopped \(name)",
      fallbackFailureMessage: "Could not stop \(name)"
    )
  }

  func stopComposeProject(project: String, workingDirectory: String?) async -> ProcessActionResult {
    guard let docker = dockerExecutablePath() else { return dockerNotFound }

    let result = await runner.run(
      docker,
      arguments: ["compose", "-p", project, "down"],
      currentDirectoryPath: workingDirectory,
      timeout: 20
    )

    return actionResult(
      result,
      successMessage: "Stopped compose project \(project)",
      fallbackFailureMessage: "Could not stop \(project)"
    )
  }

  func openDockerLogs(id: String, name: String) async -> ProcessActionResult {
    let command = "docker logs -f \(shellQuoted(id))"
    let script = """
    tell application "Terminal"
      activate
      do script "\(appleScriptEscaped(command))"
    end tell
    """

    let result = await runner.run(
      "/usr/bin/osascript",
      arguments: ["-e", script],
      timeout: 4
    )

    return actionResult(
      result,
      successMessage: "Opened logs for \(name)",
      fallbackFailureMessage: "Could not open Docker logs"
    )
  }

  func openTerminal(at path: String) async -> ProcessActionResult {
    let result = await runner.run(
      "/usr/bin/open",
      arguments: ["-a", "Terminal", path],
      timeout: 2
    )

    if result.succeeded {
      return ProcessActionResult(succeeded: true, message: "Opened Terminal")
    }

    return ProcessActionResult(succeeded: false, message: "Could not open Terminal")
  }

  private func send(signal: Int32, to pid: Int32, successMessage: String) -> ProcessActionResult {
    let result = kill(pid, signal)
    if result == 0 {
      return ProcessActionResult(succeeded: true, message: successMessage)
    }

    let error = String(cString: strerror(errno))
    return ProcessActionResult(succeeded: false, message: error)
  }

  private var dockerNotFound: ProcessActionResult {
    ProcessActionResult(succeeded: false, message: "Docker CLI not found")
  }

  private func dockerExecutablePath() -> String? {
    DockerScanner.dockerExecutablePath()
  }

  private func actionResult(
    _ result: CommandResult,
    successMessage: String,
    fallbackFailureMessage: String
  ) -> ProcessActionResult {
    if result.succeeded {
      return ProcessActionResult(succeeded: true, message: successMessage)
    }

    let message = result.trimmedStderr.isEmpty ? fallbackFailureMessage : result.trimmedStderr
    return ProcessActionResult(succeeded: false, message: DisplayFormat.clipped(message, length: 80))
  }

  private func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
  }

  private func appleScriptEscaped(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}
