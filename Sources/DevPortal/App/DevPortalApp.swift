import AppKit
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}

@main
struct DevPortalApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var store = ServerStore()
  private let updaterController: SPUStandardUpdaterController

  init() {
    Diagnostics.runIfRequested()
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  var body: some Scene {
    Window("DevPortal", id: "inspector") {
      InspectorView()
        .environmentObject(store)
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
          store.refreshIfNeeded()
          NSApp.activate(ignoringOtherApps: true)
        }
    }

    MenuBarExtra {
      MenuBarContentView(updater: updaterController.updater)
        .environmentObject(store)
        .onAppear {
          store.refreshIfNeeded()
        }
    } label: {
      Label(store.menuBarTitle, systemImage: store.menuBarSystemImage)
    }
    .menuBarExtraStyle(.menu)
  }
}
