import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    // The main status item (control icon)
    var mainStatusItem: NSStatusItem?
    var updateTimer: Timer?
    
    // Dynamic status items for each selected app with notifications
    var appStatusItems: [String: NSStatusItem] = [:]
    
    // Simulation state
    var isSimulatingMulti = false
    
    // User-selected app titles to show individually on notifications
    var selectedApps: Set<String> {
        get {
            let saved = UserDefaults.standard.stringArray(forKey: "SelectedApps") ?? []
            return Set(saved)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "SelectedApps")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the Main Status Bar Item (the bell/control icon)
        mainStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = mainStatusItem?.button {
            if let image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "SmartBadges") {
                image.isTemplate = true
                button.image = image
            }
        }
        
        checkAndStartUpdates()
    }

    func setupMainMenu(allDockApps: [AppBadgeInfo]) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "SmartBadges Active", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let sectionHeader = NSMenuItem(title: "Show Individual Notification Icons For:", action: nil, keyEquivalent: "")
        sectionHeader.isEnabled = false
        menu.addItem(sectionHeader)
        
        var uniqueAppTitles = Set(allDockApps.map { $0.title })
        uniqueAppTitles.insert("App Store")
        uniqueAppTitles.insert("WhatsApp")
        
        let currentlySelected = selectedApps
        for appTitle in uniqueAppTitles.sorted() {
            guard appTitle != "SmartBadges" && !appTitle.isEmpty else { continue }
            let item = NSMenuItem(title: appTitle, action: #selector(toggleAppSelection(_:)), keyEquivalent: "")
            item.target = self
            item.state = currentlySelected.contains(appTitle) ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Simulate App Store (5) & WhatsApp (3)", action: #selector(simulateMultiClicked), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear Simulation", action: #selector(clearSimulationClicked), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let hasPermission = AccessibilityHelper.checkAccessibilityPermissions(prompt: false)
        if !hasPermission {
            menu.addItem(NSMenuItem(title: "Check Accessibility Permission", action: #selector(checkPermissionMenuClicked), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
        }
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        mainStatusItem?.menu = menu
    }

    @objc func toggleAppSelection(_ sender: NSMenuItem) {
        let appTitle = sender.title
        var current = selectedApps
        if current.contains(appTitle) {
            current.remove(appTitle)
            sender.state = .off
        } else {
            current.insert(appTitle)
            sender.state = .on
        }
        selectedApps = current
        updateBadges()
    }

    func checkAndStartUpdates() {
        if AccessibilityHelper.checkAccessibilityPermissions(prompt: false) {
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.updateBadges()
            }
            updateBadges()
        } else {
            setupMainMenu(allDockApps: [])
            if let button = mainStatusItem?.button {
                button.title = "⚠️"
            }
        }
    }

    @objc func simulateMultiClicked() {
        isSimulatingMulti = true
        updateBadges()
    }

    @objc func clearSimulationClicked() {
        isSimulatingMulti = false
        updateBadges()
    }

    @objc func checkPermissionMenuClicked() {
        _ = AccessibilityHelper.checkAccessibilityPermissions(prompt: true)
        checkAndStartUpdates()
    }

    func updateBadges() {
        var dockApps = AccessibilityHelper.getDockAppBadges()
        
        if isSimulatingMulti {
            dockApps = dockApps.filter { $0.title != "App Store" && $0.title != "WhatsApp" }
            dockApps.append(AppBadgeInfo(title: "App Store", bundleId: nil, badgeValue: "5", appURL: URL(fileURLWithPath: "/System/Applications/App Store.app")))
            dockApps.append(AppBadgeInfo(title: "WhatsApp", bundleId: nil, badgeValue: "3", appURL: URL(fileURLWithPath: "/Applications/WhatsApp.app")))
        }
        
        setupMainMenu(allDockApps: dockApps)
        
        let currentlySelected = selectedApps
        var consolidatedCount = 0
        var individualAppsToShow: [AppBadgeInfo] = []
        
        var logContent = "--- Update Cycle \(Date()) ---\n"
        logContent += "Selected Apps: \(currentlySelected)\n"
        
        // Map dock apps by title for easy lookup
        var dockAppMap: [String: AppBadgeInfo] = [:]
        for app in dockApps {
            dockAppMap[app.title] = app
        }
        
        // Always include selected apps as individual items to keep their icons in the menu bar
        for appTitle in currentlySelected {
            if let dockApp = dockAppMap[appTitle] {
                individualAppsToShow.append(dockApp)
            } else {
                // If not currently running/in dock, try to resolve its URL for the icon
                var appURL: URL? = nil
                if let path = NSWorkspace.shared.fullPath(forApplication: appTitle) {
                    appURL = URL(fileURLWithPath: path)
                }
                individualAppsToShow.append(AppBadgeInfo(title: appTitle, bundleId: nil, badgeValue: nil, appURL: appURL))
            }
        }
        
        // Consolidated count is for non-selected apps only
        for app in dockApps {
            if !currentlySelected.contains(app.title) {
                if let val = app.badgeValue, !val.isEmpty {
                    let count = Int(val) ?? 1
                    consolidatedCount += count
                }
            }
        }
        
        // Remove individual items no longer active (i.e. deselected by the user)
        let activeIndividualTitles = Set(individualAppsToShow.map { $0.title })
        let titlesToRemove = appStatusItems.keys.filter { !activeIndividualTitles.contains($0) }
        for title in titlesToRemove {
            if let item = appStatusItems[title] {
                NSStatusBar.system.removeStatusItem(item)
            }
            appStatusItems.removeValue(forKey: title)
        }
        
        // Spawn/update individual status items
        for appInfo in individualAppsToShow {
            let title = appInfo.title
            let badgeVal = appInfo.badgeValue ?? ""
            
            let item: NSStatusItem
            if let existingItem = appStatusItems[title] {
                item = existingItem
            } else {
                item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                appStatusItems[title] = item
            }
            
            if let button = item.button {
                button.target = self
                button.action = #selector(appStatusItemClicked(_:))
                button.toolTip = title
                
                var appIcon: NSImage?
                if let appURL = appInfo.appURL {
                    appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                }
                
                if let icon = appIcon, icon.size.width > 0, icon.size.height > 0 {
                    button.image = icon.resized(to: NSSize(width: 16, height: 16))
                    let frameStr = button.window.map { "\($0.frame)" } ?? "nil"
                    logContent += "  Set Icon for \(title) at frame \(frameStr)\n"
                }
                
                if !badgeVal.isEmpty {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor.systemRed,
                        .font: NSFont.boldSystemFont(ofSize: 12)
                    ]
                    button.attributedTitle = NSAttributedString(string: badgeVal, attributes: attrs)
                    button.imagePosition = .imageLeading
                } else {
                    button.attributedTitle = NSAttributedString(string: "")
                    button.title = ""
                    button.imagePosition = .imageOnly
                }
            }
        }
        
        // Update main badge count
        if let mainButton = mainStatusItem?.button {
            if consolidatedCount > 0 {
                let attrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.systemRed,
                    .font: NSFont.boldSystemFont(ofSize: 12)
                ]
                mainButton.attributedTitle = NSAttributedString(string: "\(consolidatedCount)", attributes: attrs)
                logContent += "Consolidated Count: \(consolidatedCount)\n"
            } else {
                mainButton.attributedTitle = NSAttributedString(string: "")
                mainButton.title = ""
            }
        }
        
        try? logContent.write(toFile: "/Users/sven-ole.fedders/scripts/smartbadges/debug.log", atomically: true, encoding: .utf8)
    }

    @objc func appStatusItemClicked(_ sender: NSStatusBarButton) {
        guard let appTitle = sender.toolTip else { return }
        
        let runningApps = NSWorkspace.shared.runningApplications
        if let targetApp = runningApps.first(where: { $0.localizedName == appTitle }) {
            targetApp.activate(options: [.activateIgnoringOtherApps])
        } else {
            NSWorkspace.shared.launchApplication(appTitle)
        }
    }
}

extension NSImage {
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
