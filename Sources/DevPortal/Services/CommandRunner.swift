import Darwin
import Foundation

struct CommandResult: Equatable, Sendable {
  let stdout: String
  let stderr: String
  let exitCode: Int32
  let timedOut: Bool

  var succeeded: Bool {
    exitCode == 0 && !timedOut
  }

  var trimmedStdout: String {
    stdout.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var trimmedStderr: String {
    stderr.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

final class CommandRunner: @unchecked Sendable {
  func run(
    _ executablePath: String,
    arguments: [String] = [],
    currentDirectoryPath: String? = nil,
    timeout: TimeInterval = 3
  ) async -> CommandResult {
    await Task.detached(priority: .utility) {
      Self.runSynchronously(
        executablePath,
        arguments: arguments,
        currentDirectoryPath: currentDirectoryPath,
        timeout: timeout
      )
    }.value
  }

  private static func runSynchronously(
    _ executablePath: String,
    arguments: [String],
    currentDirectoryPath: String?,
    timeout: TimeInterval
  ) -> CommandResult {
    let process = Process()
    let stdout = Pipe()
    let stderr = Pipe()
    let semaphore = DispatchSemaphore(value: 0)

    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    if let currentDirectoryPath {
      process.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }
    process.standardOutput = stdout
    process.standardError = stderr
    process.terminationHandler = { _ in
      semaphore.signal()
    }

    do {
      try process.run()
    } catch {
      return CommandResult(
        stdout: "",
        stderr: error.localizedDescription,
        exitCode: -1,
        timedOut: false
      )
    }

    var timedOut = false
    if semaphore.wait(timeout: .now() + timeout) == .timedOut {
      timedOut = true
      if process.isRunning {
        process.terminate()
      }

      if semaphore.wait(timeout: .now() + 0.7) == .timedOut, process.isRunning {
        kill(process.processIdentifier, SIGKILL)
        process.waitUntilExit()
      }
    }

    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

    return CommandResult(
      stdout: String(data: stdoutData, encoding: .utf8) ?? "",
      stderr: String(data: stderrData, encoding: .utf8) ?? "",
      exitCode: process.terminationStatus,
      timedOut: timedOut
    )
  }
}
