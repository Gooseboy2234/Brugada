#if os(macOS)
import AppKit

/// Without this, closing the main window quits the app (the default
/// AppKit/SwiftUI behavior when the last window closes), which would defeat
/// the whole point of the menu bar extra — a Mac left running near the rig
/// should keep polling and alerting even with no window open.
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
#endif
