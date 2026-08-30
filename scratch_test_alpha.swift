import AppKit
import CoreGraphics

typealias CGSConnectionID = Int32
typealias CGError = Int32

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSetWindowAlpha")
func CGSSetWindowAlpha(_ cid: CGSConnectionID, _ wid: CGWindowID, _ alpha: Float) -> CGError

func testAlphaHiding() {
    print("=== Testing CGSSetWindowAlpha ===")
    
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return
    }
    
    var targetWindowID: CGWindowID?
    
    for info in windowList {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let ownerName = info[kCGWindowOwnerName as String] as? String,
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            continue
        }
        
        let windowName = info[kCGWindowName as String] as? String ?? ""
        
        // Target Bluetooth (width 32)
        if ownerName == "Control Center" && (windowName == "Bluetooth" || rect.size.width == 32) {
            targetWindowID = windowID
            print("Found target window (ID: \(windowID), Title: \(windowName)) at position: \(rect)")
            break
        }
    }
    
    guard let wid = targetWindowID else {
        print("Error: Target window not found.")
        return
    }
    
    let connection = _CGSDefaultConnection()
    print("Connection ID: \(connection)")
    
    // Hide
    let hideResult = CGSSetWindowAlpha(connection, wid, 0.0)
    print("Hide (0.0) Result Code: \(hideResult)")
    
    if hideResult == 0 {
        print("Success! The window should now be invisible. Waiting 5 seconds before showing it again...")
        sleep(5)
        let showResult = CGSSetWindowAlpha(connection, wid, 1.0)
        print("Show (1.0) Result Code: \(showResult)")
    } else {
        print("Failed to set window alpha. Error code: \(hideResult)")
    }
}

testAlphaHiding()
