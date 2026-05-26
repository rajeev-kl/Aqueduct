import Foundation
import ApplicationServices
import Cocoa

import Foundation
import ApplicationServices
import Cocoa

enum SnapAction {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case centerFloat
}

struct WindowSnapshot: Codable {
    let appBundleID: String
    let appName: String
    let windowTitle: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct WorkspaceSnapshot: Codable {
    let name: String
    let windows: [WindowSnapshot]
}

class WindowManager {
    static let shared = WindowManager()
    
    private init() {}
    
    func getFrontmostWindow() -> AXUIElement? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success {
            return (focusedWindow as! AXUIElement)
        }
        
        return nil
    }
    
    func setWindow(_ windowElement: AXUIElement, frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        
        // Some applications require setting size first, then position, then size again to ensure it fits within screen bounds correctly.
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeValue)
        }
        
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, positionValue)
        }
        
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeValue)
        }
    }
    
    func getScreenOfWindow(_ windowElement: AXUIElement) -> NSScreen? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return NSScreen.main
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        
        let windowFrame = CGRect(origin: position, size: size)
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        
        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 1080
        
        for screen in screens {
            let axScreenFrame = CGRect(
                x: screen.frame.origin.x,
                y: primaryHeight - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            if axScreenFrame.contains(windowCenter) {
                return screen
            }
        }
        
        return NSScreen.main
    }
    
    func snapWindow(_ windowElement: AXUIElement, action: SnapAction) {
        guard let screen = getScreenOfWindow(windowElement) else { return }
        
        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 1080
        let visibleFrame = screen.visibleFrame
        
        // Convert visibleFrame to AX coordinates (Y-down)
        let axVisible = CGRect(
            x: visibleFrame.origin.x,
            y: primaryHeight - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
        
        // Get gaps configuration
        let gap = CGFloat(UserDefaults.standard.integer(forKey: "GridGapConfig"))
        
        var targetFrame = axVisible
        
        switch action {
        case .leftHalf:
            let width = (axVisible.width - 3 * gap) / 2
            let height = axVisible.height - 2 * gap
            targetFrame = CGRect(
                x: axVisible.minX + gap,
                y: axVisible.minY + gap,
                width: width,
                height: height
            )
        case .rightHalf:
            let width = (axVisible.width - 3 * gap) / 2
            let height = axVisible.height - 2 * gap
            targetFrame = CGRect(
                x: axVisible.minX + 2 * gap + width,
                y: axVisible.minY + gap,
                width: width,
                height: height
            )
        case .topHalf:
            let width = axVisible.width - 2 * gap
            let height = (axVisible.height - 3 * gap) / 2
            targetFrame = CGRect(
                x: axVisible.minX + gap,
                y: axVisible.minY + gap,
                width: width,
                height: height
            )
        case .bottomHalf:
            let width = axVisible.width - 2 * gap
            let height = (axVisible.height - 3 * gap) / 2
            targetFrame = CGRect(
                x: axVisible.minX + gap,
                y: axVisible.minY + 2 * gap + height,
                width: width,
                height: height
            )
        case .maximize:
            targetFrame = CGRect(
                x: axVisible.minX + gap,
                y: axVisible.minY + gap,
                width: axVisible.width - 2 * gap,
                height: axVisible.height - 2 * gap
            )
        case .centerFloat:
            let width = (axVisible.width - 2 * gap) * 0.6
            let height = (axVisible.height - 2 * gap) * 0.8
            let x = axVisible.minX + (axVisible.width - width) / 2
            let y = axVisible.minY + (axVisible.height - height) / 2
            targetFrame = CGRect(
                x: x,
                y: y,
                width: width,
                height: height
            )
        }
        
        setWindow(windowElement, frame: targetFrame)
    }
    
    func throwWindowToNextScreen(_ windowElement: AXUIElement, forward: Bool = true) {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }
        
        guard let currentScreen = getScreenOfWindow(windowElement) else { return }
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }
        
        let targetIndex: Int
        if forward {
            targetIndex = (currentIndex + 1) % screens.count
        } else {
            targetIndex = (currentIndex - 1 + screens.count) % screens.count
        }
        let targetScreen = screens[targetIndex]
        
        // Get window frame
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success else {
            return
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        
        let primaryHeight = screens.first?.frame.height ?? 1080
        
        // Convert screen visible frames to AX coordinates (Y-down)
        let currentAXVisible = CGRect(
            x: currentScreen.visibleFrame.origin.x,
            y: primaryHeight - currentScreen.visibleFrame.maxY,
            width: currentScreen.visibleFrame.width,
            height: currentScreen.visibleFrame.height
        )
        
        let targetAXVisible = CGRect(
            x: targetScreen.visibleFrame.origin.x,
            y: primaryHeight - targetScreen.visibleFrame.maxY,
            width: targetScreen.visibleFrame.width,
            height: targetScreen.visibleFrame.height
        )
        
        // Calculate relative position and size of window on current screen
        let relX = (position.x - currentAXVisible.minX) / currentAXVisible.width
        let relY = (position.y - currentAXVisible.minY) / currentAXVisible.height
        let relW = size.width / currentAXVisible.width
        let relH = size.height / currentAXVisible.height
        
        // Calculate new position and size on target screen
        var newWidth = relW * targetAXVisible.width
        var newHeight = relH * targetAXVisible.height
        var newX = targetAXVisible.minX + relX * targetAXVisible.width
        var newY = targetAXVisible.minY + relY * targetAXVisible.height
        
        // Ensure the window fits within target screen bounds
        if newWidth > targetAXVisible.width { newWidth = targetAXVisible.width }
        if newHeight > targetAXVisible.height { newHeight = targetAXVisible.height }
        if newX + newWidth > targetAXVisible.maxX { newX = targetAXVisible.maxX - newWidth }
        if newY + newHeight > targetAXVisible.maxY { newY = targetAXVisible.maxY - newHeight }
        if newX < targetAXVisible.minX { newX = targetAXVisible.minX }
        if newY < targetAXVisible.minY { newY = targetAXVisible.minY }
        
        let newFrame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        setWindow(windowElement, frame: newFrame)
    }
    
    func captureWorkspace() -> [WindowSnapshot] {
        var snapshots: [WindowSnapshot] = []
        
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }
            
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            
            guard result == .success, let windows = windowsRef as? [AXUIElement] else { continue }
            
            for window in windows {
                // Get title
                var titleRef: CFTypeRef?
                var title = ""
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let t = titleRef as? String {
                    title = t
                }
                
                // Get position
                var positionRef: CFTypeRef?
                var position = CGPoint.zero
                if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success {
                    AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
                } else {
                    continue
                }
                
                // Get size
                var sizeRef: CFTypeRef?
                var size = CGSize.zero
                if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success {
                    AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
                } else {
                    continue
                }
                
                let snapshot = WindowSnapshot(
                    appBundleID: app.bundleIdentifier ?? "",
                    appName: app.localizedName ?? "",
                    windowTitle: title,
                    x: Double(position.x),
                    y: Double(position.y),
                    width: Double(size.width),
                    height: Double(size.height)
                )
                snapshots.append(snapshot)
            }
        }
        
        return snapshots
    }
    
    func restoreWorkspace(_ snapshot: WorkspaceSnapshot) {
        let runningApps = NSWorkspace.shared.runningApplications
        
        let savedWindowsByApp = Dictionary(grouping: snapshot.windows, by: { $0.appBundleID })
        
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  let savedWins = savedWindowsByApp[bundleID] else { continue }
            
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let openWindows = windowsRef as? [AXUIElement] else { continue }
            
            var remainingOpen = openWindows
            
            // First pass: exact title match
            for savedWin in savedWins {
                if let idx = remainingOpen.firstIndex(where: {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue($0, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let title = titleRef as? String {
                        return title == savedWin.windowTitle
                    }
                    return false
                }) {
                    let openWin = remainingOpen.remove(at: idx)
                    let targetFrame = CGRect(x: savedWin.x, y: savedWin.y, width: savedWin.width, height: savedWin.height)
                    setWindow(openWin, frame: targetFrame)
                }
            }
            
            // Second pass: sequential match
            let remainingSaved = savedWins
            
            for (idx, openWin) in remainingOpen.enumerated() {
                if idx < remainingSaved.count {
                    let savedWin = remainingSaved[idx]
                    let targetFrame = CGRect(x: savedWin.x, y: savedWin.y, width: savedWin.width, height: savedWin.height)
                    setWindow(openWin, frame: targetFrame)
                }
            }
        }
    }
}
