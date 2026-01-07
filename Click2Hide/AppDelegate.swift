import Cocoa
import CoreGraphics
import SwiftUI
import ApplicationServices
import Combine
import ServiceManagement
import Foundation

@main
struct Click2HideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Click2Hide", image: "MenuBarIcon") {
            Button(action: appDelegate.openPopupWindow, label: { Text("Settings") })
            Divider()
            Button(action: appDelegate.openAccessibilityPreferences, label: { Text("Accessibility Preferences") })
            Button(action: appDelegate.openAutomationPreferences, label: { Text("Automation Preferences") })
            Divider()
            Button(action: appDelegate.quitApp, label: { Text("Quit") })
        }
    }

    init() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appDelegate.currentVersion = "\(version).\(build)"
        }
        appDelegate.checkForUpdates()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var eventTap: CFMachPort?
    var mainWindow: NSWindow?
    var cancellables = Set<AnyCancellable>()
    var dockItems: [DockItem] = [] 
    private var isClickToHideEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "ClickToHideEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "ClickToHideEnabled")
            return true
        }
        return UserDefaults.standard.bool(forKey: "ClickToHideEnabled")
    }() 
    var currentVersion: String = ""
    private var debounceTimer: Timer?
    private var trustCheckTimer: Timer?
    private var hasShownPrompt = false
     
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    func openSettingsWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let contentView = ContentView()
            let hostingController = NSHostingController(rootView: contentView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Version \(currentVersion)"
            window.styleMask = [.titled, .closable]
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.mainWindow = window
        }
    }
    
    @objc func openPopupWindow() {
        openSettingsWindow()
        if let w = self.mainWindow {
            w.level = .floating
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        log("Application did finish launching v2.1 (Final Stable)")
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateClickToHideState(_:)), name: NSNotification.Name("ClickToHideStateChanged"), object: nil)

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(dockChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)

        registerLoginItem() 
        
        trustCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkTrustAndSetup()
        }
        checkTrustAndSetup()
    }

    func checkTrustAndSetup() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: !hasShownPrompt]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            if eventTap == nil {
                log("Trust established! Setting up event tap...")
                setupEventTap()
            }
            if dockItems.isEmpty {
                updateDockItems()
            }
        } else {
            if !hasShownPrompt {
                log("Permission prompt requested.")
                hasShownPrompt = true
            }
        }
    }

    @objc func dockChanged(notification: Notification) {
        updateDockItems()
    }

    @objc func updateDockItems() {
        if !AXIsProcessTrusted() { return }
        if debounceTimer == nil {
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.debounceTimer = nil
            }
            performDockUpdate()
        }
    }

    private func performDockUpdate() {
        getDockRects().sink { [weak self] dockItems in
            self?.dockItems = dockItems ?? []
            self?.log("Updated Dock Items: \(self?.dockItems.count ?? 0) found")
        }.store(in: &cancellables)
    }
    
    func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) 
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                return AppDelegate.eventTapCallback(proxy: proxy, type: type, event: event, appDelegate: appDelegate)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log("Failed to create event tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.eventTap = eventTap
        log("Event tap created successfully")
    }

    static func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent?, appDelegate: AppDelegate) -> Unmanaged<CGEvent>? {
        guard let event = event else { return nil }
        
        if !appDelegate.isClickToHideEnabled || appDelegate.isActiveAppFullscreen() {
            return Unmanaged.passUnretained(event)
        }
        
        let mouseLocation = event.location
        
        // Exact match click logic (Magnification is off per user)
        guard let matched = appDelegate.dockItems.first(where: { $0.rect.contains(mouseLocation) }) else {
            return Unmanaged.passUnretained(event)
        }
        
        if "Launchpad||Trash||Downloads||Apps||".contains(matched.appID) || matched.appID.isEmpty {
            return Unmanaged.passUnretained(event)
        }
        
        // UNIVERSAL MATCHER: Check all running apps
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { 
            // 1. Exact Name match
            $0.localizedName == matched.appID ||
            // 2. Case-insensitive match
            $0.localizedName?.lowercased() == matched.appID.lowercased() ||
            // 3. Bundle ID exact match
            $0.bundleIdentifier == matched.appID ||
            // 4. Special cases (WhatsApp, Chrome, etc. often have different IDs)
            ($0.bundleIdentifier == "net.whatsapp.WhatsApp" && matched.appID == "WhatsApp") ||
            ($0.bundleIdentifier == "com.google.Chrome" && matched.appID == "Google Chrome") ||
            // 5. Partial match for apps like "Terminal — zsh"
            $0.localizedName?.contains(matched.appID) == true ||
            matched.appID.contains($0.localizedName ?? "___") == true
        }) {
            if app.isActive && !app.isHidden {
                // IT IS ACTIVE -> HIDE IT
                appDelegate.log("Hiding: \(matched.appID)")
                app.hide()
                return nil // Intercept the click
            }
        }
        
        // IN ALL OTHER CASES: Let the macOS Dock handle the click
        // This is 100% reliable for opening/unminimizing apps
        return Unmanaged.passUnretained(event)
    }

    private func isActiveAppFullscreen() -> Bool {
        let windows = NSApplication.shared.windows.filter { $0.isVisible && $0.isKeyWindow }
        for window in windows {
            if window.styleMask.contains(.fullSizeContentView) {
                return true
            }
        }
        return false
    }

    struct DockItem {
        let rect: NSRect
        let appID: String
    }

    func log(_ message: String) {
        let logMessage = "[\(Date())] \(message)\n"
        print(message)
        let logURL = URL(fileURLWithPath: "/tmp/click2hide.log")
        if let data = logMessage.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logURL)
            }
        }
    }

    func getDockRects() -> Future<[DockItem]?, Never> {
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                var items: [DockItem] = []
                guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
                    promise(.success(nil))
                    return
                }
                
                let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
                var allLists: [AXUIElement] = []
                
                func findLists(in element: AXUIElement, depth: Int) {
                    if depth > 4 { return }
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                    if (roleRef as? String) == kAXListRole {
                        allLists.append(element)
                    }
                    var childrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                       let children = childrenRef as? [AXUIElement] {
                        for child in children { findLists(in: child, depth: depth + 1) }
                    }
                }
                
                findLists(in: dockElement, depth: 0)
                
                for list in allLists {
                    var iconsRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &iconsRef) == .success,
                       let icons = iconsRef as? [AXUIElement] {
                        for icon in icons {
                            var roleRef: CFTypeRef?
                            AXUIElementCopyAttributeValue(icon, kAXRoleAttribute as CFString, &roleRef)
                            if (roleRef as? String) != kAXDockItemRole { continue }
                            
                            var posRef: CFTypeRef?
                            var sizeRef: CFTypeRef?
                            var titleRef: CFTypeRef?
                            AXUIElementCopyAttributeValue(icon, kAXPositionAttribute as CFString, &posRef)
                            AXUIElementCopyAttributeValue(icon, kAXSizeAttribute as CFString, &sizeRef)
                            AXUIElementCopyAttributeValue(icon, kAXTitleAttribute as CFString, &titleRef)
                            
                            if let posRef = posRef, let sizeRef = sizeRef, let title = titleRef as? String {
                                let posV = posRef as! AXValue
                                let sizeV = sizeRef as! AXValue
                                var p = CGPoint.zero
                                var s = CGSize.zero
                                AXValueGetValue(posV, .cgPoint, &p)
                                AXValueGetValue(sizeV, .cgSize, &s)
                                items.append(DockItem(rect: NSRect(x: p.x, y: p.y, width: s.width, height: s.height), appID: title))
                            }
                        }
                    }
                }
                promise(.success(items))
            }
        }
    }

    func registerLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            try SMAppService.mainApp.register()
        } catch {
            log("Error setting login item: \(error.localizedDescription)")
        }
    }

    @objc func updateClickToHideState(_ notification: Notification) {
        if let enabled = notification.object as? Bool {
            isClickToHideEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "ClickToHideEnabled")
        }
    }

    func isAccessibilityEnabled() -> Bool {
        return AXIsProcessTrusted()
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openAutomationPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/victorwon/click2hide/releases/latest")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            if let releaseInfo = try? JSONDecoder().decode(Release.self, from: data) {
                if self.isNewerVersion(releaseInfo.tag_name, currentVersion: self.currentVersion) {
                    DispatchQueue.main.async { self.promptUserToUpdate(releaseInfo) }
                }
            }
        }
        task.resume()
    }

    private func isNewerVersion(_ newVersion: String, currentVersion: String) -> Bool {
        let newVersionComponents = newVersion.split(separator: ".").map { Int($0) ?? 0 }
        let currentVersionComponents = currentVersion.split(separator: ".").map { Int($0) ?? 0 }
        for (new, current) in zip(newVersionComponents, currentVersionComponents) {
            if new > current { return true } else if new < current { return false }
        }
        return newVersionComponents.count > currentVersionComponents.count
    }

    private func promptUserToUpdate(_ releaseInfo: Release) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version is available."
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "https://github.com/victorwon/click2hide/releases") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    struct Release: Codable {
        let tag_name: String
    }
}
