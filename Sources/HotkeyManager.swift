import Cocoa
import Carbon

class HotkeyManager {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    
    init() {
        setupHandler()
    }
    
    deinit {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
    }
    
    func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, action: @escaping () -> Void) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("grdt".utf8.reduce(0) { $0 << 8 + UInt32($1) }), id: id)
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
            handlers[id] = action
        } else {
            print("Failed to register hotkey with ID \(id), status: \(status)")
        }
    }
    
    private func setupHandler() {
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            let mySelf = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                if let handler = mySelf.handlers[hotKeyID.id] {
                    handler()
                    return noErr
                }
            }
            return noErr // return noErr or eventNotHandledErr
        }, 1, [eventSpec], ptr, nil)
    }
}
