import SwiftUI
import AppKit
import ServiceManagement
import Carbon

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
        
        hotkeyManager = HotkeyManager()
        
        // 1. Show Grid: Cmd+G
        hotkeyManager?.register(keyCode: 5, modifiers: UInt32(cmdKey), id: 1) { [weak self] in
            self?.toggleOverlay()
        }
        
        // 2. Snap Left Half: Ctrl+Option+Left Arrow
        hotkeyManager?.register(keyCode: 123, modifiers: UInt32(controlKey | optionKey), id: 2) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.snapWindow(window, action: .leftHalf)
            }
        }
        
        // 3. Snap Right Half: Ctrl+Option+Right Arrow
        hotkeyManager?.register(keyCode: 124, modifiers: UInt32(controlKey | optionKey), id: 3) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.snapWindow(window, action: .rightHalf)
            }
        }
        
        // 4. Snap Top Half: Ctrl+Option+Up Arrow
        hotkeyManager?.register(keyCode: 126, modifiers: UInt32(controlKey | optionKey), id: 4) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.snapWindow(window, action: .topHalf)
            }
        }
        
        // 5. Snap Bottom Half: Ctrl+Option+Down Arrow
        hotkeyManager?.register(keyCode: 125, modifiers: UInt32(controlKey | optionKey), id: 5) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.snapWindow(window, action: .bottomHalf)
            }
        }
        
        // 6. Maximize: Ctrl+Option+Enter
        hotkeyManager?.register(keyCode: 36, modifiers: UInt32(controlKey | optionKey), id: 6) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.snapWindow(window, action: .maximize)
            }
        }
        
        // 7. Center & Float: Ctrl+Option+C
        hotkeyManager?.register(keyCode: 8, modifiers: UInt32(controlKey | optionKey), id: 7) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.snapWindow(window, action: .centerFloat)
            }
        }
        
        // 8. Throw Next Screen: Ctrl+Option+Cmd+Right Arrow
        hotkeyManager?.register(keyCode: 124, modifiers: UInt32(controlKey | optionKey | cmdKey), id: 8) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.throwWindowToNextScreen(window, forward: true)
            }
        }
        
        // 9. Throw Previous Screen: Ctrl+Option+Cmd+Left Arrow
        hotkeyManager?.register(keyCode: 123, modifiers: UInt32(controlKey | optionKey | cmdKey), id: 9) {
            if let window = WindowManager.shared.getFrontmostWindow() {
                WindowManager.shared.throwWindowToNextScreen(window, forward: false)
            }
        }
    }
    
    var columnsMenu: NSMenu!
    var rowsMenu: NSMenu!
    var gapsMenu: NSMenu!
    var workspacesMenu: NSMenu!
    var deleteWorkspacesMenu: NSMenu!
    var launchAtStartupItem: NSMenuItem!
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "squareshape.split.3x3", accessibilityDescription: "ScreenSplit")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Grid (Cmd+G)", action: #selector(toggleOverlay), keyEquivalent: "g"))
        menu.items.last?.keyEquivalentModifierMask = [.command]
        
        menu.addItem(NSMenuItem.separator())
        
        // Grid Configuration
        let configItem = NSMenuItem(title: "Grid Configuration", action: nil, keyEquivalent: "")
        let configMenu = NSMenu()
        
        let columnsItem = NSMenuItem(title: "Columns", action: nil, keyEquivalent: "")
        columnsMenu = NSMenu()
        for opt in [0, 3, 4, 5, 6] {
            let title = opt == 0 ? "Auto" : "\(opt)"
            let item = NSMenuItem(title: title, action: #selector(setColumns(_:)), keyEquivalent: "")
            item.tag = opt
            item.target = self
            columnsMenu.addItem(item)
        }
        columnsItem.submenu = columnsMenu
        configMenu.addItem(columnsItem)
        
        let rowsItem = NSMenuItem(title: "Rows", action: nil, keyEquivalent: "")
        rowsMenu = NSMenu()
        for opt in [0, 3, 4, 5, 6] {
            let title = opt == 0 ? "Auto" : "\(opt)"
            let item = NSMenuItem(title: title, action: #selector(setRows(_:)), keyEquivalent: "")
            item.tag = opt
            item.target = self
            rowsMenu.addItem(item)
        }
        rowsItem.submenu = rowsMenu
        configMenu.addItem(rowsItem)
        
        let templatesItem = NSMenuItem(title: "Templates", action: nil, keyEquivalent: "")
        let templatesMenu = NSMenu()
        
        let v11 = NSMenuItem(title: "1:1 Vertical", action: #selector(setTemplate(_:)), keyEquivalent: "")
        v11.representedObject = [2, 1]
        v11.target = self
        templatesMenu.addItem(v11)
        
        let h11 = NSMenuItem(title: "1:1 Horizontal", action: #selector(setTemplate(_:)), keyEquivalent: "")
        h11.representedObject = [1, 2]
        h11.target = self
        templatesMenu.addItem(h11)
        
        let thirds = NSMenuItem(title: "1:1:1 / 1:2", action: #selector(setTemplate(_:)), keyEquivalent: "")
        thirds.representedObject = [3, 1]
        thirds.target = self
        templatesMenu.addItem(thirds)
        
        templatesItem.submenu = templatesMenu
        configMenu.addItem(templatesItem)
        
        // Window Gaps Configuration
        let gapsItem = NSMenuItem(title: "Window Gaps", action: nil, keyEquivalent: "")
        gapsMenu = NSMenu()
        let gapOptions = [
            (title: "None (0px)", value: 0),
            (title: "Small (4px)", value: 4),
            (title: "Medium (8px)", value: 8),
            (title: "Large (12px)", value: 12)
        ]
        for opt in gapOptions {
            let item = NSMenuItem(title: opt.title, action: #selector(setGap(_:)), keyEquivalent: "")
            item.tag = opt.value
            item.target = self
            gapsMenu.addItem(item)
        }
        gapsItem.submenu = gapsMenu
        configMenu.addItem(gapsItem)
        
        configItem.submenu = configMenu
        menu.addItem(configItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Workspaces Menu
        let workspacesItem = NSMenuItem(title: "Workspaces", action: nil, keyEquivalent: "")
        workspacesMenu = NSMenu()
        
        let saveWorkspaceItem = NSMenuItem(title: "Save Current Workspace...", action: #selector(saveWorkspaceAction), keyEquivalent: "")
        saveWorkspaceItem.target = self
        workspacesMenu.addItem(saveWorkspaceItem)
        
        let deleteWorkspaceItem = NSMenuItem(title: "Delete Workspace", action: nil, keyEquivalent: "")
        deleteWorkspacesMenu = NSMenu()
        deleteWorkspaceItem.submenu = deleteWorkspacesMenu
        workspacesMenu.addItem(deleteWorkspaceItem)
        
        workspacesMenu.addItem(NSMenuItem.separator())
        
        workspacesItem.submenu = workspacesMenu
        menu.addItem(workspacesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Launch at startup
        launchAtStartupItem = NSMenuItem(title: "Launch at Startup", action: #selector(toggleLaunchAtStartup), keyEquivalent: "")
        launchAtStartupItem.target = self
        menu.addItem(launchAtStartupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit ScreenSplit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        updateMenuStates()
    }
    
    @objc func toggleLaunchAtStartup() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                } else {
                    try SMAppService.mainApp.register()
                }
                updateMenuStates()
            } catch {
                print("Failed to toggle launch at startup: \(error)")
            }
        } else {
            print("Launch at startup requires macOS 13.0 or later.")
        }
    }
    
    @objc func setColumns(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "GridColumnsConfig")
        updateMenuStates()
    }
    
    @objc func setRows(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "GridRowsConfig")
        updateMenuStates()
    }
    
    @objc func setTemplate(_ sender: NSMenuItem) {
        if let config = sender.representedObject as? [Int], config.count == 2 {
            UserDefaults.standard.set(config[0], forKey: "GridColumnsConfig")
            UserDefaults.standard.set(config[1], forKey: "GridRowsConfig")
            updateMenuStates()
        }
    }
    
    @objc func setGap(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "GridGapConfig")
        updateMenuStates()
    }
    
    @objc func saveWorkspaceAction() {
        promptForWorkspaceName { [weak self] name in
            guard let self = self, let name = name else { return }
            
            let windows = WindowManager.shared.captureWorkspace()
            let newWorkspace = WorkspaceSnapshot(name: name, windows: windows)
            
            var workspaces = self.loadWorkspaces()
            workspaces[name] = newWorkspace
            
            if let data = try? JSONEncoder().encode(workspaces) {
                UserDefaults.standard.set(data, forKey: "WorkspaceSnapshots")
            }
            
            self.updateMenuStates()
        }
    }
    
    @objc func deleteWorkspaceAction(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        
        var workspaces = loadWorkspaces()
        workspaces.removeValue(forKey: name)
        
        if let data = try? JSONEncoder().encode(workspaces) {
            UserDefaults.standard.set(data, forKey: "WorkspaceSnapshots")
        }
        
        updateMenuStates()
    }
    
    @objc func restoreWorkspaceAction(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let workspaces = loadWorkspaces()
        if let workspace = workspaces[name] {
            WindowManager.shared.restoreWorkspace(workspace)
        }
    }
    
    func loadWorkspaces() -> [String: WorkspaceSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: "WorkspaceSnapshots") else { return [:] }
        return (try? JSONDecoder().decode([String: WorkspaceSnapshot].self, from: data)) ?? [:]
    }
    
    func promptForWorkspaceName(completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save Workspace Snapshot"
        alert.informativeText = "Enter a name for this workspace snapshot:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        inputTextField.placeholderString = "Coding / Browsing / etc."
        alert.accessoryView = inputTextField
        
        // Force alert to front
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = inputTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(name.isEmpty ? nil : name)
        } else {
            completion(nil)
        }
    }
    
    func updateMenuStates() {
        let cols = UserDefaults.standard.integer(forKey: "GridColumnsConfig")
        let rows = UserDefaults.standard.integer(forKey: "GridRowsConfig")
        let gaps = UserDefaults.standard.integer(forKey: "GridGapConfig")
        
        for item in columnsMenu.items {
            item.state = (item.tag == cols) ? .on : .off
        }
        
        for item in rowsMenu.items {
            item.state = (item.tag == rows) ? .on : .off
        }
        
        for item in gapsMenu.items {
            item.state = (item.tag == gaps) ? .on : .off
        }
        
        if #available(macOS 13.0, *) {
            launchAtStartupItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        
        // Update workspaces menu dynamic items
        while workspacesMenu.items.count > 3 {
            workspacesMenu.removeItem(at: 3)
        }
        deleteWorkspacesMenu.removeAllItems()
        
        let workspaces = loadWorkspaces()
        if workspaces.isEmpty {
            let noWorkspacesItem = NSMenuItem(title: "No saved workspaces", action: nil, keyEquivalent: "")
            noWorkspacesItem.isEnabled = false
            workspacesMenu.addItem(noWorkspacesItem)
            
            let noDeleteWorkspacesItem = NSMenuItem(title: "No saved workspaces", action: nil, keyEquivalent: "")
            noDeleteWorkspacesItem.isEnabled = false
            deleteWorkspacesMenu.addItem(noDeleteWorkspacesItem)
        } else {
            for name in workspaces.keys.sorted() {
                let restoreItem = NSMenuItem(title: name, action: #selector(restoreWorkspaceAction(_:)), keyEquivalent: "")
                restoreItem.representedObject = name
                restoreItem.target = self
                workspacesMenu.addItem(restoreItem)
                
                let deleteItem = NSMenuItem(title: name, action: #selector(deleteWorkspaceAction(_:)), keyEquivalent: "")
                deleteItem.representedObject = name
                deleteItem.target = self
                deleteWorkspacesMenu.addItem(deleteItem)
            }
        }
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
