import AppKit
import CoreGraphics

func checkScreenRecordingAccess() {
    print("=== Checking Screen Recording Access ===")
    
    if #available(macOS 10.15, *) {
        let hasAccess = CGPreflightScreenCaptureAccess()
        print("Screen Recording Access Granted: \(hasAccess)")
        
        if !hasAccess {
            print("Requesting access (this should trigger a system dialog)...")
            let requested = CGRequestScreenCaptureAccess()
            print("Request triggered. Result: \(requested)")
        }
    } else {
        print("macOS version is older than 10.15, Screen Recording access check not required.")
    }
}

checkScreenRecordingAccess()
