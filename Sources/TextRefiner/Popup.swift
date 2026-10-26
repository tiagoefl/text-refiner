import AppKit

final class RefinementController {
    private let popup = RefinementPopup()

    func refineSelection() {
        if let text = SelectedTextReader.accessibilitySelection() {
            request(text)
        } else {
            SelectedTextReader.clipboardFallback { [weak self] text in
                guard let text else { showError("Select some text first."); return }
                self?.request(text)
            }
        }
    }

    private func request(_ text: String) {
        popup.showLoading()
        Task { @MainActor in
            do { popup.show(try await OpenAIService.refine(text)) }
            catch { popup.close(); showError(error.localizedDescription) }
        }
    }
}

final class RefinementPopup: NSObject {
    private let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 250),
                                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private var outsideMonitor: Any?
    private var localMonitor: Any?

    override init() {
        super.init()
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hasShadow = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isOpaque = false
    }

    func showLoading() {
        install(content: ["Refining…"])
        present()
    }

    func show(_ values: Refinements) {
        install(content: ["Shorter|\(values.shorter)", "Clearer|\(values.clearer)", "More formal|\(values.formal)"])
        present()
    }

    private func install(content: [String]) {
        let view = NSStackView()
        view.orientation = .vertical
        view.spacing = 8
        view.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        for value in content {
            let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
            let button = NSButton(title: parts.count == 2 ? "\(parts[0])\n\(parts[1])" : parts[0], target: self, action: #selector(copyChoice(_:)))
            button.alignment = .left
            button.tag = view.arrangedSubviews.count
            button.setButtonType(.momentaryPushIn)
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 13)
            button.contentTintColor = .labelColor
            button.toolTip = parts.count == 2 ? parts[1] : nil
            button.representedObject = parts.last
            view.addArrangedSubview(button)
        }
        panel.contentView = view
        panel.setContentSize(NSSize(width: 440, height: max(70, CGFloat(content.count) * 70 + 26)))
    }

    private func present() {
        let point = NSEvent.mouseLocation
        panel.setFrameTopLeftPoint(NSPoint(x: point.x - 220, y: point.y - 12))
        panel.orderFrontRegardless()
        watchForDismissal()
    }

    @objc private func copyChoice(_ sender: NSButton) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        close()
    }

    private func watchForDismissal() {
        closeMonitors()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.close() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown && event.keyCode == 53 { self.close(); return nil }
            if event.window !== self.panel { self.close() }
            return event
        }
    }

    func close() { panel.orderOut(nil); closeMonitors() }
    private func closeMonitors() {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor); self.outsideMonitor = nil }
        if let localMonitor { NSEvent.removeMonitor(localMonitor); self.localMonitor = nil }
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
