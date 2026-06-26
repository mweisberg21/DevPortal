import Darwin
import Foundation

enum Diagnostics {
  static func runIfRequested() {
    guard CommandLine.arguments.contains("--scan-once") else {
      return
    }

    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = DiagnosticResultBox()

    Task.detached(priority: .utility) {
      let snapshot = await ServerScanner().scan()
      resultBox.set(output: Self.render(snapshot), exitCode: 0)
      semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + 15) == .timedOut {
      fputs("DevPortal scan timed out\n", stderr)
      exit(1)
    }

    let result = resultBox.get()
    print(result.output)
    exit(result.exitCode)
  }

  private static func render(_ snapshot: ServerSnapshot) -> String {
    var lines: [String] = []
    lines.append("DevPortal scan")
    lines.append("Web Dev Servers: \(snapshot.webPorts.count)")
    lines.append(contentsOf: snapshot.webPorts.map(renderLocalPort))
    lines.append("Docker: \(snapshot.dockerContainers.count)")

    if let dockerMessage = snapshot.dockerStatus.message, snapshot.dockerContainers.isEmpty {
      lines.append("- \(dockerMessage)")
    } else {
      lines.append(contentsOf: snapshot.dockerContainers.map(renderDockerContainer))
    }

    lines.append("Other Local Ports: \(snapshot.otherPorts.count)")
    lines.append(contentsOf: snapshot.otherPorts.map(renderLocalPort))
    return lines.joined(separator: "\n")
  }

  private static func renderLocalPort(_ port: LocalPort) -> String {
    let url = port.openURL?.absoluteString ?? "no-url"
    let cwd = port.cwd.map { DisplayFormat.compactPath($0, maxLength: 80) } ?? "unknown"
    let branch = port.source.gitBranch.map { " branch=\($0)" } ?? ""
    let kind = port.source.commandKind.map { " kind=\($0)" } ?? ""
    return "- \(port.displayName) :\(port.port) pid=\(port.pid) url=\(url) cwd=\(cwd)\(branch)\(kind)"
  }

  private static func renderDockerContainer(_ container: DockerContainer) -> String {
    let ports = container.ports.map(\.displayValue).joined(separator: ", ")
    let compose = container.composeProject.map { " compose=\($0)" } ?? ""
    return "- \(container.name) image=\(container.image)\(compose) ports=\(ports.isEmpty ? "none" : ports)"
  }
}

private final class DiagnosticResultBox: @unchecked Sendable {
  private let lock = NSLock()
  private var output = "scan timed out"
  private var exitCode: Int32 = 1

  func set(output: String, exitCode: Int32) {
    lock.withLock {
      self.output = output
      self.exitCode = exitCode
    }
  }

  func get() -> (output: String, exitCode: Int32) {
    lock.withLock {
      (output, exitCode)
    }
  }
}
