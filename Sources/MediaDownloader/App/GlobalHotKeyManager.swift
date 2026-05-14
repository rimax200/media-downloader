import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    deinit {
        unregister()
    }

    func registerActivationHotKey(_ shortcut: HotKeyShortcut = HotKeyAction.activateApp.defaultShortcut) {
        unregister()

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard hotKeyID.signature == GlobalHotKeyManager.hotKeySignature,
                      hotKeyID.id == GlobalHotKeyManager.activationHotKeyID else {
                    return noErr
                }

                let manager = Unmanaged<GlobalHotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                DispatchQueue.main.async {
                    manager.action()
                }

                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            NSLog("Failed to install global hotkey handler: \(handlerStatus)")
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: Self.activationHotKeyID
        )

        let hotKeyStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyStatus != noErr {
            NSLog("Failed to register activation hotkey \(shortcut.displayText): \(hotKeyStatus)")
            removeEventHandler()
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        removeEventHandler()
    }

    private func removeEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static let activationHotKeyID: UInt32 = 1
    private static let hotKeySignature: OSType = {
        let scalars = Array("MDLR".unicodeScalars).map(\.value)
        return scalars.reduce(0) { ($0 << 8) + OSType($1) }
    }()
}

private extension HotKeyShortcut {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0

        if modifiers.contains(.command) {
            flags |= UInt32(cmdKey)
        }

        if modifiers.contains(.shift) {
            flags |= UInt32(shiftKey)
        }

        if modifiers.contains(.option) {
            flags |= UInt32(optionKey)
        }

        if modifiers.contains(.control) {
            flags |= UInt32(controlKey)
        }

        return flags
    }
}
