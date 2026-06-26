// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "DevPortal",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "DevPortal", targets: ["DevPortal"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3")
  ],
  targets: [
    .executableTarget(
      name: "DevPortal",
      dependencies: [
        .product(name: "Sparkle", package: "Sparkle")
      ],
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
      ]
    ),
    .testTarget(name: "DevPortalTests", dependencies: ["DevPortal"])
  ]
)
