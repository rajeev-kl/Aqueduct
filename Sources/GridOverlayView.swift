import SwiftUI

struct GridSelection {
    var startColumn: Int
    var startRow: Int
    var endColumn: Int
    var endRow: Int
    
    func contains(col: Int, row: Int) -> Bool {
        let minCol = min(startColumn, endColumn)
        let maxCol = max(startColumn, endColumn)
        let minRow = min(startRow, endRow)
        let maxRow = max(startRow, endRow)
        
        return col >= minCol && col <= maxCol && row >= minRow && row <= maxRow
    }
}

struct GridOverlayView: View {
    var onConfirm: (CGRect) -> Void
    var onCancel: () -> Void
    
    @State private var selection: GridSelection?
    @State private var dragStart: CGPoint?
    @State private var localEventMonitor: Any?
    
    @AppStorage("GridColumnsConfig") private var columnsConfig: Int = 0
    @AppStorage("GridRowsConfig") private var rowsConfig: Int = 0
    @AppStorage("GridGapConfig") private var gapConfig: Int = 0
    
    var gridPadding: CGFloat {
        return CGFloat(gapConfig)
    }
    
    var gridSpacing: CGFloat {
        return CGFloat(gapConfig)
    }
    
    // Dynamic grid size based on screen
    var columns: Int {
        if columnsConfig > 0 { return columnsConfig }
        if let screen = NSScreen.main {
            return max(4, Int(screen.visibleFrame.width / 400))
        }
        return 8
    }
    
    var rows: Int {
        if rowsConfig > 0 { return rowsConfig }
        if let screen = NSScreen.main {
            return max(3, Int(screen.visibleFrame.height / 300))
        }
        return 4
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            let confirmSelection = {
                guard let sel = selection else { return }
                
                let cellWidth = (geometry.size.width - (gridPadding * 2) - CGFloat(columns - 1) * gridSpacing) / CGFloat(columns)
                let cellHeight = (geometry.size.height - (gridPadding * 2) - CGFloat(rows - 1) * gridSpacing) / CGFloat(rows)
                
                let minCol = min(sel.startColumn, sel.endColumn)
                let maxCol = max(sel.startColumn, sel.endColumn)
                let minRow = min(sel.startRow, sel.endRow)
                let maxRow = max(sel.startRow, sel.endRow)
                
                let windowScreen = NSApp.windows.first(where: { $0.isKeyWindow || $0.level == .floating })?.screen ?? NSScreen.main!
                
                let width = CGFloat(maxCol - minCol + 1) * cellWidth + CGFloat(maxCol - minCol) * gridSpacing
                let height = CGFloat(maxRow - minRow + 1) * cellHeight + CGFloat(maxRow - minRow) * gridSpacing
                
                let localX = gridPadding + CGFloat(minCol) * (cellWidth + gridSpacing)
                let localY = gridPadding + CGFloat(minRow) * (cellHeight + gridSpacing)
                
                let primaryScreen = NSScreen.screens[0]
                let screenTopLeftX = windowScreen.visibleFrame.minX
                let screenTopLeftY = primaryScreen.frame.height - windowScreen.visibleFrame.maxY
                
                let globalX = screenTopLeftX + localX
                let globalY = screenTopLeftY + localY
                
                let finalRect = CGRect(x: globalX, y: globalY, width: width, height: height)
                
                onConfirm(finalRect)
                
                selection = nil
                dragStart = nil
            }
            
            ZStack {
                // Dim the screen slightly but leave gaps mostly transparent
                Color.black.opacity(0.15)
                
                // Grid
                VStack(spacing: gridSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: gridSpacing) {
                            ForEach(0..<columns, id: \.self) { col in
                                Rectangle()
                                    .fill(
                                        (selection?.contains(col: col, row: row) == true)
                                        ? Color.blue.opacity(0.85)
                                        : Color.black.opacity(0.55)
                                    )
                                    .border(
                                        (selection?.contains(col: col, row: row) == true)
                                        ? Color.white.opacity(0.8)
                                        : Color.white.opacity(0.25),
                                        width: 1
                                    )
                            }
                        }
                    }
                }
                .padding(gridPadding)
            }
            .contentShape(Rectangle()) // Make entire area clickable
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        
                        let cellWidth = (geometry.size.width - (gridPadding * 2) - CGFloat(columns - 1) * gridSpacing) / CGFloat(columns)
                        let cellHeight = (geometry.size.height - (gridPadding * 2) - CGFloat(rows - 1) * gridSpacing) / CGFloat(rows)
                        
                        let startCol = max(0, min(columns - 1, Int((value.startLocation.x - gridPadding) / (cellWidth + gridSpacing))))
                        let startRow = max(0, min(rows - 1, Int((value.startLocation.y - gridPadding) / (cellHeight + gridSpacing))))
                        
                        let endCol = max(0, min(columns - 1, Int((value.location.x - gridPadding) / (cellWidth + gridSpacing))))
                        let endRow = max(0, min(rows - 1, Int((value.location.y - gridPadding) / (cellHeight + gridSpacing))))
                        
                        selection = GridSelection(startColumn: startCol, startRow: startRow, endColumn: endCol, endRow: endRow)
                    }
                    .onEnded { _ in
                        confirmSelection()
                    }
            )
            .onAppear {
                localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    let keyCode = event.keyCode
                    let isShift = event.modifierFlags.contains(.shift)
                    
                    // Return (Enter)
                    if keyCode == 36 {
                        confirmSelection()
                        return nil
                    }
                    
                    // Escape
                    if keyCode == 53 {
                        selection = nil
                        dragStart = nil
                        onCancel()
                        return nil
                    }
                    
                    // Arrow keys: Left 123, Right 124, Down 125, Up 126
                    if [123, 124, 125, 126].contains(keyCode) {
                        if selection == nil {
                            // Start with center
                            let c = columns / 2
                            let r = rows / 2
                            selection = GridSelection(startColumn: c, startRow: r, endColumn: c, endRow: r)
                            return nil
                        }
                        
                        var sel = selection!
                        
                        if isShift {
                            // Expand/shrink endColumn/endRow
                            switch keyCode {
                            case 123: // Left
                                sel.endColumn = max(0, sel.endColumn - 1)
                            case 124: // Right
                                sel.endColumn = min(columns - 1, sel.endColumn + 1)
                            case 125: // Down
                                sel.endRow = min(rows - 1, sel.endRow + 1)
                            case 126: // Up
                                sel.endRow = max(0, sel.endRow - 1)
                            default: break
                            }
                        } else {
                            // Move whole selection block
                            let minC = min(sel.startColumn, sel.endColumn)
                            let maxC = max(sel.startColumn, sel.endColumn)
                            let minR = min(sel.startRow, sel.endRow)
                            let maxR = max(sel.startRow, sel.endRow)
                            
                            let width = maxC - minC
                            let height = maxR - minR
                            
                            var newMinC = minC
                            var newMinR = minR
                            
                            switch keyCode {
                            case 123: // Left
                                newMinC = max(0, minC - 1)
                            case 124: // Right
                                newMinC = min(columns - 1 - width, minC + 1)
                            case 125: // Down
                                newMinR = min(rows - 1 - height, minR + 1)
                            case 126: // Up
                                newMinR = max(0, minR - 1)
                            default: break
                            }
                            
                            sel.startColumn = newMinC
                            sel.endColumn = newMinC + width
                            sel.startRow = newMinR
                            sel.endRow = newMinR + height
                        }
                        
                        selection = sel
                        return nil
                    }
                    
                    return event
                }
            }
            .onDisappear {
                if let monitor = localEventMonitor {
                    NSEvent.removeMonitor(monitor)
                    localEventMonitor = nil
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
