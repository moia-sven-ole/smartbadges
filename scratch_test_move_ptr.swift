import AppKit
import CoreGraphics

typealias CGSConnectionID = Int32
typealias CGError = Int32

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

// Correct C pointer signature: passing a pointer to CGPoint
@_silgen_name("CGSMoveWindow")
func CGSMoveWindow(_ cid: CGSConnectionID, _ wid: CGWindowID, _ point: UnsafePointer<CGPoint>) -> CGError

func testMovePointer() {
    print("=== Testing CGSMoveWindow with CGPoint Pointer ===")
    
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return
    }
    
    var targetWindowID: CGWindowID?
    var originalPoint = CGPoint.zero
    
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
            originalPoint = rect.origin
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
    var offscreenPoint = CGPoint(x: -10000.0, y: -10000.0)
    print("Moving Bluetooth offscreen to x: -10000.0, y: -10000.0 using pointer...")
    let hideResult = CGSMoveWindow(connection, wid, &offscreenPoint)
    print("Move Offscreen Result Code: \(hideResult)")
    
    if hideResult == 0 {
        print("Success! Bluetooth should have disappeared. Check your screen now! Reverting in 5 seconds...")
        sleep(5)
        var revertPoint = originalPoint
        let showResult = CGSMoveWindow(connection, wid, &revertPoint)
        print("Revert Move Result Code: \(showResult)")
    } else {
        print("Failed to move window. Error code: \(hideResult)")
    }
}

testMovePointer()
