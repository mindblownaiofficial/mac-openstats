import AppKit

/// Quits or force-quits a process shown in the Top Processes list.
enum ProcessControl {
    @MainActor
    static func quit(_ row: ProcessRow, force: Bool, store: StatsStore) {
        if force {
            let alert = NSAlert()
            alert.messageText = "Force quit “\(row.name)”?"
            alert.informativeText = "The process will be ended immediately. Any unsaved changes will be lost."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Force Quit")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        var succeeded: Bool
        if let app = NSRunningApplication(processIdentifier: row.pid) {
            // A regular app: ask it to quit (it may prompt to save), or pull the plug.
            succeeded = force ? app.forceTerminate() : app.terminate()
        } else {
            // Background process or helper: fall back to signals.
            succeeded = kill(row.pid, force ? SIGKILL : SIGTERM) == 0
        }

        if !succeeded {
            let alert = NSAlert()
            alert.messageText = "Couldn’t \(force ? "force quit" : "quit") “\(row.name)”"
            alert.informativeText = errno == EPERM
                ? "This process belongs to the system or another user, so OpenStats isn’t allowed to end it."
                : String(cString: strerror(errno))
            alert.alertStyle = .informational
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }

        // Give the process a moment to exit, then refresh the list.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { store.refreshNow() }
    }
}
