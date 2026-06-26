import Foundation
import ServiceManagement

enum LaunchAtLoginController {
  static var statusText: String {
    switch SMAppService.mainApp.status {
    case .enabled:
      return "Enabled"
    case .notRegistered:
      return "Off"
    case .requiresApproval:
      return "Needs Approval"
    case .notFound:
      return "Unavailable"
    @unknown default:
      return "Unknown"
    }
  }

  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static func setEnabled(_ enabled: Bool) -> ProcessActionResult {
    do {
      if enabled {
        if SMAppService.mainApp.status != .enabled {
          try SMAppService.mainApp.register()
        }
        return ProcessActionResult(succeeded: true, message: "Launch at login enabled")
      } else {
        if SMAppService.mainApp.status != .notRegistered {
          try SMAppService.mainApp.unregister()
        }
        return ProcessActionResult(succeeded: true, message: "Launch at login disabled")
      }
    } catch {
      return ProcessActionResult(
        succeeded: false,
        message: DisplayFormat.clipped(error.localizedDescription, length: 80)
      )
    }
  }
}
