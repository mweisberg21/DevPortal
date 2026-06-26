import Foundation

enum LocalPortClassifier {
  private static let devExecutableNames: Set<String> = [
    "node", "npm", "pnpm", "yarn", "bun", "deno",
    "vite", "next", "astro", "nuxt", "svelte", "webpack", "parcel", "remix",
    "tsx", "ts-node", "turbo", "wrangler",
    "python", "uvicorn", "fastapi", "flask", "django", "gunicorn", "hypercorn",
    "ruby", "rails", "puma", "jekyll",
    "php", "artisan", "hugo", "go run", "air"
  ]

  private static let devPortHints: Set<Int> = [
    3000, 3001, 3002, 3333,
    4321, 4747, 5000, 5001, 5173, 5174, 5175,
    8000, 8001, 8080, 8081, 8787, 8888, 9000
  ]

  static func category(
    processName: String,
    command: String,
    cwd: String?,
    port: Int
  ) -> LocalPortCategory {
    let haystack = [
      processName,
      command,
      cwd ?? ""
    ].joined(separator: " ").lowercased()

    if looksLikeDesktopAppHelper(processName: processName, command: command)
      || looksLikeSystemProcess(haystack) {
      return .otherLocal
    }

    if devExecutableNames.contains(processName.lowercased())
      || devExecutableNames.contains(commandExecutableName(command)) {
      return .webDevelopment
    }

    if looksLikeDevCommand(command) {
      return .webDevelopment
    }

    if devPortHints.contains(port) {
      return .webDevelopment
    }

    return .otherLocal
  }

  static func isDockerBridge(processName: String, command: String) -> Bool {
    let haystack = "\(processName) \(command)".lowercased()
    return haystack.contains("docker")
      || haystack.contains("com.docker")
      || haystack.contains("vpnkit")
  }

  private static func looksLikeSystemProcess(_ value: String) -> Bool {
    let systemHints = [
      "controlcenter",
      "rapportd",
      "sharingd",
      "airplay",
      "mDNSResponder".lowercased()
    ]

    return systemHints.contains { value.contains($0) }
  }

  private static func looksLikeDesktopAppHelper(processName: String, command: String) -> Bool {
    let command = command.lowercased()
    let processName = processName.lowercased()
    return command.contains("/applications/")
      && command.contains(".app/contents/")
      && processName.contains("helper")
  }

  private static func commandExecutableName(_ command: String) -> String {
    guard let firstToken = command.split(separator: " ").first else {
      return ""
    }

    let executable = String(firstToken)
    return URL(fileURLWithPath: executable).lastPathComponent.lowercased()
  }

  private static func looksLikeDevCommand(_ command: String) -> Bool {
    let command = command.lowercased()
    let patterns = [
      #"(^|\s)(next|vite|astro|nuxt|remix|svelte-kit)\s+(dev|preview|start)\b"#,
      #"(^|\s)(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|start|preview)\b"#,
      #"(^|\s)(uvicorn|gunicorn|hypercorn)\b"#,
      #"(^|\s)(flask|django-admin|rails|puma|wrangler)\b"#,
      #"/node_modules/\.bin/(next|vite|astro|nuxt|remix|webpack|parcel)\b"#
    ]

    return patterns.contains { pattern in
      command.range(of: pattern, options: .regularExpression) != nil
    }
  }
}
