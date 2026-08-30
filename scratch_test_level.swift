import AppKit
import CoreGraphics

typealias CGSConnectionID = Int32
typealias CGError = Int32

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

@_silgen_name("CGSSetWindowLevel")
func CGSSetWindowLevel(_ cid: CGSConnectionID, _ wid: CGWindowID, _ level: Int32) -> CGError

func testLayerHiding() {
    print("=== Testing CGSSetWindowLevel ===")
    
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
    
    // Put behind wallpaper (Desktop level = -2147483648, or just standard app level = 0, or negative level = -100)
    print("Moving Bluetooth window layer behind the desktop...")
    let hideResult = CGSSetWindowLevel(connection, wid, -100)
    print("Change Level Result Code: \(hideResult)")
    
    if hideResult == 0 {
        print("Success! Check if Bluetooth disappeared. Reverting to menu bar layer (25) in 5 seconds...")
        sleep(5)
        let showResult = CGSSetWindowLevel(connection, wid, 25)
        print("Revert Level Result Code: \(showResult)")
    } else {
        print("Failed to change window level. Error code: \(hideResult)")
    }
}

testLayerHiding()
