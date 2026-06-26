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
  targets: [
    .executableTarget(name: "DevPortal"),
    .testTarget(name: "DevPortalTests", dependencies: ["DevPortal"])
  ]
)
