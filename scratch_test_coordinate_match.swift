import AppKit
import ApplicationServices
import CoreGraphics

func testCoordinates() {
    print("=== Core Graphics Windows ===")
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return
    }
    
    var cgWindows: [String: CGRect] = [:]
    for info in windowList {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let ownerName = info[kCGWindowOwnerName as String] as? String,
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            continue
        }
        
        let isAtTop = rect.origin.y >= 0 && rect.origin.y < 50
        let isMenuBarSize = rect.size.height > 15 && rect.size.height < 50
        
        if ownerName == "Control Center" && isAtTop && isMenuBarSize {
            let windowName = info[kCGWindowName as String] as? String ?? "NoName"
            print("CG Window - ID: \(windowID), Name: \"\(windowName)\", Frame: \(rect)")
        }
    }
    
    print("\n=== Accessibility Elements ===")
    let apps = NSWorkspace.shared.runningApplications
    guard let controlCenter = apps.first(where: { $0.localizedName == "Control Center" }) else {
        print("Control Center process not found")
        return
    }
    
    let pid = controlCenter.processIdentifier
    let appElement = AXUIElementCreateApplication(pid)
    
    var childrenRef: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef)
    if status == .success, let children = childrenRef as? [AXUIElement] {
        for child in children {
            traverse(element: child)
        }
    }
}

func traverse(element: AXUIElement) {
    var roleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
    let role = roleRef as? String ?? ""
    
    var titleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
    var title = titleRef as? String ?? ""
    
    if title.isEmpty {
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef)
        title = descRef as? String ?? ""
    }
    
    if !title.isEmpty && (role == "AXMenuBarItem" || role == "AXButton" || role == "AXCheckBox") {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        let posStatus = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        let sizeStatus = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        if posStatus == .success, sizeStatus == .success,
           let pos = positionRef, let sz = sizeRef {
            let posVal = pos as! AXValue
            let sizeVal = sz as! AXValue
            
            var point = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(posVal, .cgPoint, &point)
            AXValueGetValue(sizeVal, .cgSize, &size)
            
            print("AX Element - Role: \(role), Title/Desc: \"\(title)\", Origin: \(point), Size: \(size)")
        }
    }
    
    var childrenRef: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
    if status == .success, let children = childrenRef as? [AXUIElement] {
        for child in children {
            traverse(element: child)
        }
    }
}

testCoordinates()
