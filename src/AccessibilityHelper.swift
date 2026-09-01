import AppKit
import ApplicationServices

struct AppBadgeInfo {
    let title: String
    let bundleId: String?
    let badgeValue: String?
    let appURL: URL?
}

class AccessibilityHelper {
    
    /// Checks if the app currently has accessibility permissions.
    static func checkAccessibilityPermissions(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Gets notification badge info from all apps currently displayed in the Dock.
    static func getDockAppBadges() -> [AppBadgeInfo] {
        var results: [AppBadgeInfo] = []
        
        // Find the Dock application
        let dockApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
        guard let dockApp = dockApps.first else {
            print("Dock application not found.")
            return results
        }
        
        let pid = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(pid)
        
        var listRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &listRef)
        guard status == .success, let children = listRef as? [AXUIElement] else {
            return results
        }
        
        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            
            guard let role = roleRef as? String, role == kAXListRole else {
                continue
            }
            
            var dockItemsRef: CFTypeRef?
            let itemStatus = AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &dockItemsRef)
            guard itemStatus == .success, let dockItems = dockItemsRef as? [AXUIElement] else {
                continue
            }
            
            for item in dockItems {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                let title = titleRef as? String ?? "Unknown App"
                
                // Get the status label (the badge value)
                var badgeRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &badgeRef)
                let badgeValue = badgeRef as? String
                
                // Get the app URL
                var urlRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, "AXURL" as CFString, &urlRef)
                let appURL = urlRef as? URL
                
                results.append(AppBadgeInfo(title: title, bundleId: appURL.flatMap { Bundle(url: $0)?.bundleIdentifier }, badgeValue: badgeValue, appURL: appURL))
            }
        }
        
        return results
    }
    
    /// Brings an application into the foreground reliably using multiple mechanisms:
    /// 1. Triggering AXPress on its Dock item (macOS native unhide, unminimize, and window reopen).
    /// 2. Unhiding, activating, and raising all windows via Accessibility APIs.
    /// 3. LaunchServices / NSWorkspace openApplication with activation configuration.
    /// 4. AppleScript reopen + activate fallback.
    static func activateApp(title: String, bundleId: String? = nil, appURL: URL? = nil) {
        // 1. Try Dock item press via Accessibility (handles macOS-native activation, unminimize, unhide, reopen)
        let dockApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
        if let dockApp = dockApps.first {
            let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
            var listRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &listRef) == .success,
               let children = listRef as? [AXUIElement] {
                for child in children {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
                    if let role = roleRef as? String, role == kAXListRole {
                        var dockItemsRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &dockItemsRef) == .success,
                           let dockItems = dockItemsRef as? [AXUIElement] {
                            for item in dockItems {
                                var titleRef: CFTypeRef?
                                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                                if let itemTitle = titleRef as? String,
                                   itemTitle.localizedCaseInsensitiveCompare(title) == .orderedSame {
                                    let actionResult = AXUIElementPerformAction(item, kAXPressAction as CFString)
                                    if actionResult == .success {
                                        return
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Find running app instance
        let runningApps = NSWorkspace.shared.runningApplications
        let targetApp = runningApps.first(where: {
            $0.localizedName?.localizedCaseInsensitiveCompare(title) == .orderedSame ||
            $0.bundleURL?.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveCompare(title) == .orderedSame ||
            (bundleId != nil && $0.bundleIdentifier == bundleId)
        })
        
        if let app = targetApp {
            if app.isHidden {
                app.unhide()
            }
            
            // Raise windows using Accessibility
            let appRef = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows {
                    AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
                }
            }
            
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
        
        // 3. Resolve target URL and open via LaunchServices
        var resolvedURL = appURL ?? targetApp?.bundleURL
        if resolvedURL == nil {
            if let bId = bundleId ?? targetApp?.bundleIdentifier {
                resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId)
            }
        }
        if resolvedURL == nil {
            let candidatePaths = [
                "/Applications/\(title).app",
                "/System/Applications/\(title).app",
                "/System/Applications/Utilities/\(title).app",
                "\(NSHomeDirectory())/Applications/\(title).app"
            ]
            for path in candidatePaths {
                if FileManager.default.fileExists(atPath: path) {
                    resolvedURL = URL(fileURLWithPath: path)
                    break
                }
            }
        }
        
        if let targetURL = resolvedURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            config.promptsUserIfNeeded = false
            NSWorkspace.shared.openApplication(at: targetURL, configuration: config, completionHandler: nil)
        }
        
        // 4. AppleScript fallback to reopen & activate
        let targetBundleId = bundleId ?? targetApp?.bundleIdentifier
        let scriptSource = (targetBundleId != nil) ?
            "tell application id \"\(targetBundleId!)\" to reopen\ntell application id \"\(targetBundleId!)\" to activate" :
            "tell application \"\(title)\" to reopen\ntell application \"\(title)\" to activate"
        
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
}
