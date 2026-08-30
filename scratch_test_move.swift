import AppKit
import CoreGraphics

typealias CGSConnectionID = Int32
typealias CGError = Int32

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

// The correct signature: passing X and Y as separate Double (CGFloat) values
@_silgen_name("CGSMoveWindow")
func CGSMoveWindow(_ cid: CGSConnectionID, _ wid: CGWindowID, _ x: Double, _ y: Double) -> CGError

func testMoveHiding() {
    print("=== Testing CGSMoveWindow ===")
    
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return
    }
    
    var targetWindowID: CGWindowID?
    var originalX = 0.0
    var originalY = 0.0
    
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
            originalX = Double(rect.origin.x)
            originalY = Double(rect.origin.y)
            print("Found Bluetooth (ID: \(windowID)) at position: \(rect)")
            break
        }
    }
    
    guard let wid = targetWindowID else {
        print("Error: Bluetooth window not found.")
        return
    }
    
    let connection = _CGSDefaultConnection()
    print("Connection ID: \(connection)")
    
    // Move offscreen to hide
    print("Moving Bluetooth offscreen to x: -10000.0, y: -10000.0...")
    let hideResult = CGSMoveWindow(connection, wid, -10000.0, -10000.0)
    print("Move Offscreen Result Code: \(hideResult)")
    
    if hideResult == 0 {
        print("Success! Bluetooth should have disappeared. Check your screen now! Reverting in 5 seconds...")
        sleep(5)
        let showResult = CGSMoveWindow(connection, wid, originalX, originalY)
        print("Revert Move Result Code: \(showResult)")
    } else {
        print("Failed to move window. Error code: \(hideResult)")
    }
}

testMoveHiding()
