import Testing
@testable import DevPortal
import Foundation

@Suite("Parsing and classification")
struct ParsingTests {
  @Test("lsof parser dedupes repeated descriptors")
  func lsofParserDedupesRepeatedDescriptors() {
    let output = """
    p2561
    cnode
    u501
    f12
    PTCP
    n*:4747
    f13
    PTCP
    n*:4747
    p3996
    cDiscord Helper (Renderer)
    u501
    f40
    PTCP
    n127.0.0.1:6463
    """

    let listeners = LsofParser.parseListeners(output)

    #expect(listeners.count == 2)
    #expect(listeners[0].pid == 2561)
    #expect(listeners[0].processName == "node")
    #expect(listeners[0].host == "*")
    #expect(listeners[0].port == 4747)
    #expect(listeners[1].host == "127.0.0.1")
    #expect(listeners[1].port == 6463)
  }

  @Test("host parser handles IPv4 wildcard and IPv6")
  func hostParserHandlesCommonAddressShapes() throws {
    let wildcard = try #require(LsofParser.parseHostPort("*:3000"))
    let ipv4 = try #require(LsofParser.parseHostPort("127.0.0.1:5173"))
    let ipv6 = try #require(LsofParser.parseHostPort("[::1]:8080"))

    #expect(wildcard.host == "*")
    #expect(wildcard.port == 3000)
    #expect(ipv4.host == "127.0.0.1")
    #expect(ipv4.port == 5173)
    #expect(ipv6.host == "::1")
    #expect(ipv6.port == 8080)
  }

  @Test("Docker parser extracts mapped host ports")
  func dockerParserExtractsMappedPorts() {
    let mappings = DockerPortParser.parsePorts("0.0.0.0:8080->80/tcp, [::]:8080->80/tcp, 5432/tcp")

    #expect(mappings.count == 2)
    #expect(mappings[0].host == "0.0.0.0")
    #expect(mappings[0].hostPort == 8080)
    #expect(mappings[0].containerPort == 80)
    #expect(mappings[0].proto == "tcp")
    #expect(mappings[1].host == "::")
  }

  @Test("Docker container parser sorts mapped containers first")
  func dockerContainerParserSortsMappedContainersFirst() {
    let output = """
    {"ID":"b","Image":"redis:7","Command":"redis-server","Names":"cache","Ports":"6379/tcp","Status":"Up 1 minute"}
    {"ID":"a","Image":"nginx:latest","Command":"nginx","Names":"web","Ports":"0.0.0.0:8080->80/tcp","Status":"Up 2 minutes","Labels":"com.docker.compose.project=site,com.docker.compose.service=web,com.docker.compose.project.working_dir=/tmp/site"}
    """

    let containers = DockerPortParser.parseContainers(output)

    #expect(containers.map(\.name) == ["web", "cache"])
    #expect(containers[0].ports.first?.hostPort == 8080)
    #expect(containers[0].composeProject == "site")
    #expect(containers[0].composeService == "web")
    #expect(containers[0].composeWorkingDirectory == "/tmp/site")
  }

  @Test("classifier separates dev servers from system ports")
  func classifierSeparatesDevServersFromSystemPorts() {
    let next = LocalPortClassifier.category(
      processName: "node",
      command: "next dev --port 3000",
      cwd: "/Users/example/site",
      port: 3000
    )
    let controlCenter = LocalPortClassifier.category(
      processName: "ControlCenter",
      command: "/System/Library/CoreServices/ControlCenter.app",
      cwd: nil,
      port: 5000
    )

    #expect(next == .webDevelopment)
    #expect(controlCenter == .otherLocal)
  }

  @Test("classifier does not mistake Electron app helpers for dev servers")
  func classifierDoesNotMistakeElectronHelpersForDevServers() {
    let discord = LocalPortClassifier.category(
      processName: "Discord Helper (Renderer)",
      command: "/Applications/Discord.app/Contents/Frameworks/Discord Helper (Renderer).app/Contents/MacOS/Discord Helper (Renderer) --enable-node-leakage-in-renderers",
      cwd: "/",
      port: 6463
    )
    let linear = LocalPortClassifier.category(
      processName: "Linear Helper",
      command: "/Applications/Linear.app/Contents/Frameworks/Linear Helper.app/Contents/MacOS/Linear Helper --utility-sub-type=node.mojom.NodeService",
      cwd: "/",
      port: 44450
    )

    #expect(discord == .otherLocal)
    #expect(linear == .otherLocal)
  }

  @Test("URL host formatter normalizes local listeners")
  func urlHostFormatterNormalizesLocalListeners() {
    #expect(DisplayFormat.urlHost(for: "*") == "localhost")
    #expect(DisplayFormat.urlHost(for: "0.0.0.0") == "localhost")
    #expect(DisplayFormat.urlHost(for: "::1") == "localhost")
    #expect(DisplayFormat.urlHost(for: "fe80::1") == "[fe80::1]")
  }

  @Test("source resolver recognizes common dev commands")
  func sourceResolverRecognizesCommonDevCommands() {
    #expect(SourceResolver.inferCommandKind(command: "pnpm next dev --port 3000", processName: "node", port: 3000) == "Next.js")
    #expect(SourceResolver.inferCommandKind(command: "uvicorn app:app --reload", processName: "python", port: 8000) == "Uvicorn")
  }

  @Test("visibility rules match ports and processes")
  func visibilityRulesMatchPortsAndProcesses() {
    let server = makeLocalPort()

    #expect(VisibilityRule(mode: .hide, target: .port, value: "3000").matches(server))
    #expect(VisibilityRule(mode: .hide, target: .process, value: "node").matches(server))
    #expect(VisibilityRule(mode: .hide, target: .folder, value: "site").matches(server))
  }

  @Test("model search matching covers server and history fields")
  func modelSearchMatchingCoversServerAndHistoryFields() {
    let server = makeLocalPort()
    let history = ServerHistoryRecord(
      id: "history",
      title: "Site :3000",
      kind: "Web Dev Servers",
      port: 3000,
      url: "http://localhost:3000",
      processName: "node",
      folder: "/tmp/site",
      firstSeenAt: Date(timeIntervalSince1970: 0),
      lastSeenAt: Date(timeIntervalSince1970: 10)
    )

    #expect(server.matchesSearch("next"))
    #expect(server.matchesSearch("3000"))
    #expect(history.matchesSearch("localhost"))
    #expect(!history.matchesSearch("postgres"))
  }

  @Test("new server notifications ignore Docker containers without mapped ports")
  func newServerNotificationsIgnoreDockerContainersWithoutMappedPorts() {
    let server = makeLocalPort()
    let unmappedContainer = makeDockerContainer(id: "a", name: "worker", ports: [])
    let mappedContainer = makeDockerContainer(
      id: "b",
      name: "web",
      ports: [
        DockerPortMapping(host: "0.0.0.0", hostPort: 8080, containerPort: 80, proto: "tcp")
      ]
    )
    let snapshot = ServerSnapshot(
      scannedAt: nil,
      webPorts: [server],
      dockerContainers: [unmappedContainer, mappedContainer],
      otherPorts: [],
      dockerStatus: .available
    )

    #expect(snapshot.dockerContainersWithMappedPorts.map(\.name) == ["web"])
    #expect(snapshot.newServerNotificationTrackingIDs.contains(server.trackingID))
    #expect(snapshot.newServerNotificationTrackingIDs.contains(mappedContainer.trackingID))
    #expect(!snapshot.newServerNotificationTrackingIDs.contains(unmappedContainer.trackingID))
  }

  @Test("duration formatter stays compact")
  func durationFormatterStaysCompact() {
    let start = Date(timeIntervalSince1970: 0)
    #expect(DisplayFormat.duration(from: start, to: Date(timeIntervalSince1970: 45)) == "45s")
    #expect(DisplayFormat.duration(from: start, to: Date(timeIntervalSince1970: 125)) == "2m")
    #expect(DisplayFormat.duration(from: start, to: Date(timeIntervalSince1970: 7_500)) == "2h 5m")
  }

  @Test("process controller can interrupt an owned process")
  func processControllerCanInterruptOwnedProcess() async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
    process.arguments = ["30"]
    try process.run()

    defer {
      if process.isRunning {
        process.terminate()
      }
    }

    let result = ProcessController().interrupt(pid: process.processIdentifier)
    #expect(result.succeeded)

    for _ in 0..<20 where process.isRunning {
      try await Task.sleep(for: .milliseconds(50))
    }

    #expect(!process.isRunning)
  }

  private func makeLocalPort() -> LocalPort {
    LocalPort(
      pid: 123,
      parentPID: nil,
      processName: "node",
      command: "next dev",
      cwd: "/tmp/site",
      host: "*",
      port: 3000,
      userID: 501,
      category: .webDevelopment,
      isOwnedByCurrentUser: true,
      isDockerBridge: false,
      source: .unknown,
      firstSeenAt: nil
    )
  }

  private func makeDockerContainer(id: String, name: String, ports: [DockerPortMapping]) -> DockerContainer {
    DockerContainer(
      id: id,
      name: name,
      image: "example:latest",
      command: "example",
      status: "Up 1 minute",
      ports: ports,
      composeProject: nil,
      composeService: nil,
      composeWorkingDirectory: nil,
      composeConfigFiles: nil,
      firstSeenAt: nil
    )
  }
}
