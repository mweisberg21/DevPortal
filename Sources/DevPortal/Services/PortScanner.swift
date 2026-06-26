import Darwin
import Foundation

final class PortScanner: @unchecked Sendable {
  private let runner: CommandRunner

  init(runner: CommandRunner) {
    self.runner = runner
  }

  func scan() async -> [LocalPort] {
    let result = await runner.run(
      "/usr/sbin/lsof",
      arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcuPn"],
      timeout: 4
    )

    guard result.succeeded else {
      return []
    }

    let rawListeners = LsofParser.parseListeners(result.stdout)
    let uniquePIDs = Array(Set(rawListeners.map(\.pid))).sorted()
    var detailsByPID: [Int32: ProcessDetails] = [:]

    for pid in uniquePIDs {
      detailsByPID[pid] = await loadDetails(for: pid)
    }

    let currentUserID = getuid()
    return rawListeners
      .compactMap { raw in
        let details = detailsByPID[raw.pid] ?? ProcessDetails.empty
        let command = details.command.isEmpty ? raw.processName : details.command
        let category = LocalPortClassifier.category(
          processName: raw.processName,
          command: command,
          cwd: details.cwd,
          port: raw.port
        )
        let isDockerBridge = LocalPortClassifier.isDockerBridge(
          processName: raw.processName,
          command: command
        )

        return LocalPort(
          pid: raw.pid,
          parentPID: details.parentPID,
          processName: raw.processName,
          command: command,
          cwd: details.cwd,
          host: raw.host,
          port: raw.port,
          userID: raw.userID,
          category: category,
          isOwnedByCurrentUser: raw.userID == currentUserID,
          isDockerBridge: isDockerBridge,
          source: SourceResolver.resolve(
            cwd: details.cwd,
            command: command,
            processName: raw.processName,
            port: raw.port
          ),
          firstSeenAt: nil
        )
      }
      .sorted { left, right in
        if left.category != right.category {
          return left.category == .webDevelopment
        }

        if left.port != right.port {
          return left.port < right.port
        }

        return left.processName.localizedCaseInsensitiveCompare(right.processName) == .orderedAscending
      }
  }

  private func loadDetails(for pid: Int32) async -> ProcessDetails {
    return ProcessDetails(
      command: await loadCommand(for: pid),
      cwd: await loadWorkingDirectory(for: pid),
      parentPID: await loadParentPID(for: pid)
    )
  }

  private func loadCommand(for pid: Int32) async -> String {
    let result = await runner.run(
      "/bin/ps",
      arguments: ["-p", "\(pid)", "-o", "command="],
      timeout: 1.5
    )

    return result.trimmedStdout
  }

  private func loadParentPID(for pid: Int32) async -> Int32? {
    let result = await runner.run(
      "/bin/ps",
      arguments: ["-p", "\(pid)", "-o", "ppid="],
      timeout: 1.5
    )

    return Int32(result.trimmedStdout)
  }

  private func loadWorkingDirectory(for pid: Int32) async -> String? {
    let result = await runner.run(
      "/usr/sbin/lsof",
      arguments: ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"],
      timeout: 1.5
    )

    guard result.succeeded else {
      return nil
    }

    return result.stdout
      .split(separator: "\n")
      .map(String.init)
      .first { $0.hasPrefix("n") }
      .map { String($0.dropFirst()) }
  }
}

private struct ProcessDetails {
  let command: String
  let cwd: String?
  let parentPID: Int32?

  static let empty = ProcessDetails(command: "", cwd: nil, parentPID: nil)
}
