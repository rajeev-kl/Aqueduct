import SwiftUI
import AppKit

@main
struct ScreenSplitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var overlayWindowController: GridOverlayWindowController?
    var hotkeyManager: HotkeyManager?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Ensure only one instance of the app runs at a time
        let bundleID = Bundle.main.bundleIdentifier ?? "com.rajeev.ScreenSplit"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        if runningApps.count > 1 {
            // Another instance is already running, exit this one immediately
            print("Another instance is already running. Exiting.")
            NSApp.terminate(nil)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request Accessibility permissions if not granted
        if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) {
            print("Accessibility permissions not granted. Prompting user.")
        }
        
        setupMenu()
        
        overlayWindowController = GridOverlayWindowController()
        
        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleOverlay()
        }
    }
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "squareshape.split.3x3", accessibilityDescription: "ScreenSplit")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Grid (Cmd+G)", action: #selector(toggleOverlay), keyEquivalent: "g"))
        menu.items.last?.keyEquivalentModifierMask = [.command]
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ScreenSplit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func toggleOverlay() {
        if overlayWindowController?.window?.isVisible == true {
            overlayWindowController?.close()
        } else {
            overlayWindowController?.showWindow(nil)
            overlayWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
