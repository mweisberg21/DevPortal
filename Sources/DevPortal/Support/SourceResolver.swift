import Foundation

enum SourceResolver {
  static func resolve(
    cwd: String?,
    command: String,
    processName: String,
    port: Int
  ) -> SourceSummary {
    let projectPath = projectPath(from: cwd)
    let package = projectPath.flatMap(readPackage)
    let gitBranch = projectPath.flatMap(readGitBranch)
    let packageScript = inferPackageScript(from: command, scripts: package?.scripts ?? [:])
    let commandKind = inferCommandKind(command: command, processName: processName, port: port)
    let displayName = displayName(
      projectPath: projectPath,
      packageName: package?.name,
      processName: processName,
      commandKind: commandKind
    )

    return SourceSummary(
      displayName: displayName,
      projectName: package?.name,
      projectPath: projectPath,
      gitBranch: gitBranch,
      packageScript: packageScript,
      packageManager: inferPackageManager(from: command, projectPath: projectPath),
      commandKind: commandKind
    )
  }

  static func inferCommandKind(command: String, processName: String, port: Int) -> String? {
    let value = "\(processName) \(command)".lowercased()
    let pairs: [(String, String)] = [
      ("next", "Next.js"),
      ("vite", "Vite"),
      ("astro", "Astro"),
      ("nuxt", "Nuxt"),
      ("remix", "Remix"),
      ("svelte", "SvelteKit"),
      ("wrangler", "Cloudflare Wrangler"),
      ("uvicorn", "Uvicorn"),
      ("fastapi", "FastAPI"),
      ("flask", "Flask"),
      ("django", "Django"),
      ("rails", "Rails"),
      ("puma", "Puma"),
      ("hugo", "Hugo")
    ]

    if let match = pairs.first(where: { value.contains($0.0) }) {
      return match.1
    }

    if processName.lowercased() == "node" {
      return "Node"
    }

    if [3000, 5173, 8000, 8080].contains(port) {
      return "Dev Server"
    }

    return nil
  }

  private static func projectPath(from cwd: String?) -> String? {
    guard let cwd, cwd != "/" else {
      return nil
    }

    return cwd
  }

  private static func displayName(
    projectPath: String?,
    packageName: String?,
    processName: String,
    commandKind: String?
  ) -> String {
    if let projectPath,
       let folder = projectPath.split(separator: "/").last,
       !folder.isEmpty {
      if let commandKind {
        return "\(folder) - \(commandKind)"
      }

      return String(folder)
    }

    if let packageName, !packageName.isEmpty {
      return packageName
    }

    return processName
  }

  private static func readPackage(at projectPath: String) -> PackageInfo? {
    let packageURL = URL(fileURLWithPath: projectPath, isDirectory: true)
      .appendingPathComponent("package.json")

    guard let data = try? Data(contentsOf: packageURL),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }

    let name = object["name"] as? String
    let scripts = object["scripts"] as? [String: String] ?? [:]
    return PackageInfo(name: name, scripts: scripts)
  }

  private static func inferPackageScript(from command: String, scripts: [String: String]) -> String? {
    let command = command.lowercased()
    let scriptNames = scripts.keys.sorted { $0.count > $1.count }

    for script in scriptNames {
      let lower = script.lowercased()
      let patterns = [
        "run \(lower)",
        "npm \(lower)",
        "pnpm \(lower)",
        "yarn \(lower)",
        "bun \(lower)"
      ]

      if patterns.contains(where: command.contains) {
        return script
      }
    }

    return nil
  }

  private static func inferPackageManager(from command: String, projectPath: String?) -> String? {
    let command = command.lowercased()
    if command.contains("pnpm") { return "pnpm" }
    if command.contains("yarn") { return "yarn" }
    if command.contains("bun") { return "bun" }
    if command.contains("npm") { return "npm" }

    guard let projectPath else {
      return nil
    }

    let managerFiles: [(String, String)] = [
      ("pnpm-lock.yaml", "pnpm"),
      ("yarn.lock", "yarn"),
      ("bun.lockb", "bun"),
      ("package-lock.json", "npm")
    ]

    return managerFiles.first { file, _ in
      FileManager.default.fileExists(atPath: URL(fileURLWithPath: projectPath).appendingPathComponent(file).path)
    }?.1
  }

  private static func readGitBranch(at projectPath: String) -> String? {
    var current = URL(fileURLWithPath: projectPath, isDirectory: true)

    while current.path != "/" {
      let gitURL = current.appendingPathComponent(".git")
      var isDirectory: ObjCBool = false

      if FileManager.default.fileExists(atPath: gitURL.path, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
          return readBranchFromGitDirectory(gitURL)
        }

        return nil
      }

      current.deleteLastPathComponent()
    }

    return nil
  }

  private static func readBranchFromGitDirectory(_ gitURL: URL) -> String? {
    let headURL = gitURL.appendingPathComponent("HEAD")
    guard let head = try? String(contentsOf: headURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines) else {
      return nil
    }

    let prefix = "ref: refs/heads/"
    if head.hasPrefix(prefix) {
      return String(head.dropFirst(prefix.count))
    }

    return head.isEmpty ? nil : String(head.prefix(8))
  }
}

private struct PackageInfo {
  let name: String?
  let scripts: [String: String]
}
