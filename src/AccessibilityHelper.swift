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
                
                results.append(AppBadgeInfo(title: title, bundleId: nil, badgeValue: badgeValue, appURL: appURL))
            }
        }
        
        return results
    }
}
