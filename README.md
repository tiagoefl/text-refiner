# Text Refiner — macOS starter utility

A native AppKit menu-bar utility that runs on **Cmd-Shift-F**, reads the current selection, requests three refinements, and places the clicked result on the clipboard. It intentionally never writes back into the originating editor.

## Run it

1. Open this folder in Xcode, or run `swift run` in Terminal.
2. Click the new menu-bar icon and choose **Set OpenAI API key…**. The key is saved as a generic-password item in the user’s Keychain; it is not bundled into the app or written to a preferences file.
3. Approve the Accessibility prompt in **System Settings → Privacy & Security → Accessibility**. Quit and relaunch after changing that setting if the event tap did not start.
4. Select text in an app and press **Cmd-Shift-F**. Click an alternative to copy it, then paste it yourself. Click anywhere outside the panel (or press Escape) to dismiss it.

## How capture works

The preferred route reads `kAXSelectedTextAttribute` from the focused accessibility element. Applications vary in their support of that attribute. If unavailable, the fallback temporarily sends Cmd-C, reads the plain-text clipboard, restores the prior pasteboard items, and then calls the API. That fallback needs Accessibility access and can be fragile in apps that intercept Copy, so test against your target apps.

## Production refinements worth adding

- Replace the hard-coded `gpt-5-mini` model in `OpenAIAndKeychain.swift` with the model enabled for your API project, or expose it in Settings.
- Add a response JSON schema (`text.format`) once you choose the model and API version, so malformed JSON is impossible rather than merely handled.
- Add a small in-panel error state and cancellation if a newer shortcut arrives while a request is pending.
- Sign/notarize the app; the stable bundle identifier will also make the Accessibility and Keychain permissions predictable.
- Consider a user-visible privacy note: selected text is sent to the configured OpenAI API project.

## Design choices

- **Global hotkey:** a `CGEvent` event tap sees Cmd-Shift-F and consumes it, avoiding conflicts in the active app. The app prompts for Accessibility approval rather than using a third-party hotkey library.
- **Popup:** a floating, non-activating `NSPanel` remains above the editor without making Text Refiner the active app. Local and global mouse monitors plus Escape implement click-outside dismissal.
- **Clipboard:** selecting a result replaces the clipboard contents with that result, as requested. The original editor contents are left untouched.

## Caveats

This is a starter for a locally installed personal tool, not a completed notarized product. An API key inside a distributed client can be extracted by a determined user; for a multi-user product, route API calls through your server with per-user authentication and rate limits instead.
