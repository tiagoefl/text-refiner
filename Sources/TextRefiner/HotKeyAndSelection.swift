import AppKit
import ApplicationServices

final class HotKeyMonitor {
    static let shared = HotKeyMonitor()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var onPress: (() -> Void)?

    func start(onPress: @escaping () -> Void) {
        self.onPress = onPress
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                 options: .defaultTap, eventsOfInterest: mask,
                                 callback: { _, type, event, userInfo in
            guard type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 3,
                  event.flags.contains(.maskCommand), event.flags.contains(.maskShift) else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async { monitor.onPress?() }
            return nil // consume Cmd-Shift-F so the frontmost app does not also handle it
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())

        guard let tap else {
            showError("The global shortcut could not start. Enable Text Refiner in Privacy & Security → Accessibility, then reopen it.")
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

enum SelectedTextReader {
    static func accessibilitySelection() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    // Some apps omit kAXSelectedTextAttribute. This temporarily invokes Copy, reads it,
    // then restores the previous pasteboard contents before the picker appears.
    static func clipboardFallback(completion: @escaping (String?) -> Void) {
        let board = NSPasteboard.general
        let saved = board.pasteboardItems?.map(PasteboardItemSnapshot.init) ?? []
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: down)! // C
            event.flags = .maskCommand
            event.post(tap: .cghidEventTap)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120)) {
            let copied = board.string(forType: .string)
            board.clearContents()
            board.writeObjects(saved.map(\.item))
            completion(copied?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? copied : nil)
        }
    }
}

private struct PasteboardItemSnapshot {
    let item: NSPasteboardItem
    init(_ source: NSPasteboardItem) {
        item = NSPasteboardItem()
        for type in source.types {
            if let data = source.data(forType: type) { item.setData(data, forType: type) }
        }
    }
}
