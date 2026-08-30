import AppKit
import CoreGraphics

typealias CGSConnectionID = Int32
typealias CGError = Int32

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSetWindowAlpha")
func CGSSetWindowAlpha(_ cid: CGSConnectionID, _ wid: CGWindowID, _ alpha: Float) -> CGError

@_silgen_name("CGSMoveWindow")
func CGSMoveWindow(_ cid: CGSConnectionID, _ wid: CGWindowID, _ point: CGPoint) -> CGError

func testHiding() {
    print("=== Testing Menu Bar Window Hiding ===")
    
    // Find the Bluetooth window
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        print("Failed to get window list")
        return
    }
    
    var bluetoothWindowID: CGWindowID?
    var originalRect = CGRect.zero
    
    for info in windowList {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let ownerName = info[kCGWindowOwnerName as String] as? String,
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
            continue
        }
        
        let windowName = info[kCGWindowName as String] as? String ?? ""
        
        // Match Bluetooth or a standard item
        if ownerName == "Control Center" && (windowName == "Bluetooth" || rect.size.width == 32) {
            bluetoothWindowID = windowID
            originalRect = rect
            print("Found Bluetooth / Target window (ID: \(windowID)) at position: \(rect)")
            break
        }
    }
    
    guard let wid = bluetoothWindowID else {
        print("Error: Target window (Bluetooth) not found in on-screen window list.")
        return
    }
    
    let connection = _CGSDefaultConnection()
    print("Connection ID: \(connection)")
    
    // Test 1: CGSSetWindowAlpha
    let alphaResult = CGSSetWindowAlpha(connection, wid, 0.0)
    print("Test 1 - CGSSetWindowAlpha (0.0) result: \(alphaResult)")
    
    // Test 2: CGSMoveWindow offscreen
    let moveResult = CGSMoveWindow(connection, wid, CGPoint(x: -10000, y: -10000))
    print("Test 2 - CGSMoveWindow (offscreen) result: \(moveResult)")
}

testHiding()
