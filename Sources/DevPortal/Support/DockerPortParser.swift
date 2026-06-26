import Foundation

enum DockerPortParser {
  static func parseContainers(_ output: String) -> [DockerContainer] {
    let decoder = JSONDecoder()

    return output
      .split(separator: "\n")
      .compactMap { line -> DockerContainer? in
        guard let data = String(line).data(using: .utf8),
              let row = try? decoder.decode(DockerPSRow.self, from: data) else {
          return nil
        }

        return DockerContainer(
          id: row.id,
          name: row.names,
          image: row.image,
          command: row.command,
          status: row.status,
          ports: parsePorts(row.ports),
          composeProject: row.labelsDictionary["com.docker.compose.project"],
          composeService: row.labelsDictionary["com.docker.compose.service"],
          composeWorkingDirectory: row.labelsDictionary["com.docker.compose.project.working_dir"],
          composeConfigFiles: row.labelsDictionary["com.docker.compose.project.config_files"],
          firstSeenAt: nil
        )
      }
      .sorted { left, right in
        if left.ports.isEmpty != right.ports.isEmpty {
          return !left.ports.isEmpty
        }

        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
      }
  }

  static func parsePorts(_ ports: String) -> [DockerPortMapping] {
    ports
      .split(separator: ",")
      .compactMap { component -> DockerPortMapping? in
        parsePortComponent(String(component).trimmingCharacters(in: .whitespacesAndNewlines))
      }
  }

  private static func parsePortComponent(_ component: String) -> DockerPortMapping? {
    guard component.contains("->") else {
      return nil
    }

    let pieces = component.split(separator: ">", maxSplits: 1).map(String.init)
    guard pieces.count == 2 else {
      return nil
    }

    let hostSide = pieces[0].trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    let containerSide = pieces[1]
    guard let hostPort = parseTrailingPort(hostSide) else {
      return nil
    }

    let host = parseHost(hostSide)
    let containerPieces = containerSide.split(separator: "/", maxSplits: 1).map(String.init)
    let containerPort = Int(containerPieces.first ?? "")
    let proto = containerPieces.count > 1 ? containerPieces[1] : "tcp"

    return DockerPortMapping(
      host: host,
      hostPort: hostPort,
      containerPort: containerPort,
      proto: proto
    )
  }

  private static func parseTrailingPort(_ value: String) -> Int? {
    if let bracket = value.lastIndex(of: "]"),
       bracket < value.endIndex,
       let colon = value[value.index(after: bracket)...].firstIndex(of: ":") {
      return Int(value[value.index(after: colon)...])
    }

    guard let colon = value.lastIndex(of: ":") else {
      return nil
    }

    return Int(value[value.index(after: colon)...])
  }

  private static func parseHost(_ value: String) -> String {
    if value.hasPrefix("["),
       let bracket = value.firstIndex(of: "]") {
      let host = value[value.index(after: value.startIndex)..<bracket]
      return String(host)
    }

    if value.hasPrefix(":::") {
      return "::"
    }

    guard let colon = value.lastIndex(of: ":") else {
      return "localhost"
    }

    let host = String(value[..<colon])
    return host.isEmpty ? "localhost" : host
  }
}

private struct DockerPSRow: Decodable {
  let id: String
  let image: String
  let command: String
  let names: String
  let ports: String
  let status: String
  let labels: String?

  var labelsDictionary: [String: String] {
    guard let labels else {
      return [:]
    }

    var result: [String: String] = [:]
    for label in labels.split(separator: ",").map(String.init) {
      let parts = label.split(separator: "=", maxSplits: 1).map(String.init)
      guard parts.count == 2 else {
        continue
      }

      result[parts[0]] = parts[1]
    }

    return result
  }

  enum CodingKeys: String, CodingKey {
    case id = "ID"
    case image = "Image"
    case command = "Command"
    case names = "Names"
    case ports = "Ports"
    case status = "Status"
    case labels = "Labels"
  }
}
