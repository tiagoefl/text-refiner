import AppKit

@main
struct TextRefinerApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // Menu-bar utility; no Dock icon.
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = RefinementController()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: "Text Refiner")

        let menu = NSMenu()
        let refineItem = menu.addItem(withTitle: "Refine selected text", action: #selector(refineNow), keyEquivalent: "")
        refineItem.target = self
        let keyItem = menu.addItem(withTitle: "Set OpenAI API key…", action: #selector(setAPIKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Text Refiner", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        HotKeyMonitor.shared.start { [weak self] in self?.controller.refineSelection() }
    }

    @objc private func refineNow() { controller.refineSelection() }

    @objc private func setAPIKey() {
        let alert = NSAlert()
        alert.messageText = "OpenAI API key"
        alert.informativeText = "Stored only in this Mac’s Keychain."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        field.stringValue = KeychainStore.shared.read() ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            do { try KeychainStore.shared.save(field.stringValue) }
            catch { showError("Couldn’t save the API key: \(error.localizedDescription)") }
        }
    }
}

func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Text Refiner"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
}
