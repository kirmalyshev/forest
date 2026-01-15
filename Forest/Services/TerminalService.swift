import Foundation

@Observable
final class TerminalService {
    static let shared = TerminalService()

    private init() {
        // Start with Terminal.app always available, refresh others in background
        installedTerminals = [.terminal]
        refreshInstalledTerminals()
    }

    private(set) var installedTerminals: Set<Terminal> = []

    func refreshInstalledTerminals() {
        // Run terminal detection on background thread to avoid blocking main thread
        // and causing SwiftUI run loop issues with waitUntilExit()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var installed: Set<Terminal> = [.terminal]
            for terminal in Terminal.allCases where terminal != .terminal {
                if self?.checkTerminalInstalled(terminal) == true {
                    installed.insert(terminal)
                }
            }
            DispatchQueue.main.async {
                self?.installedTerminals = installed
            }
        }
    }

    func isTerminalInstalled(_ terminal: Terminal) -> Bool {
        // For synchronous checks, use cached value
        installedTerminals.contains(terminal)
    }

    private func checkTerminalInstalled(_ terminal: Terminal) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemCFBundleIdentifier == '\(terminal.bundleId)'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            // Read pipe data BEFORE waitUntilExit to avoid pipe buffer deadlock
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch { return false }
    }

    func openTerminal(at path: String, preferredTerminal: Terminal? = nil) -> String? {
        let terminal = preferredTerminal ?? getDefaultTerminal()
        guard installedTerminals.contains(terminal) else {
            return "Terminal '\(terminal.displayName)' is not installed"
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", terminal.rawValue, path]
        do { try process.run(); return nil }
        catch { return "Could not open \(terminal.displayName)" }
    }

    func runInTerminal(_ script: String, preferredTerminal: Terminal? = nil) -> String? {
        let terminal = preferredTerminal ?? getDefaultTerminal()
        guard installedTerminals.contains(terminal) else {
            return "Terminal '\(terminal.displayName)' is not installed"
        }
        guard terminal.supportsAppleScript else {
            return openTerminal(at: "~", preferredTerminal: terminal)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", getAppleScript(for: terminal, script: script)]
        do { try process.run(); return nil }
        catch { return "Could not run script in \(terminal.displayName)" }
    }

    private func getDefaultTerminal() -> Terminal {
        let preferred = SettingsService.shared.defaultTerminal
        if installedTerminals.contains(preferred) { return preferred }
        let order: [Terminal] = [.iterm, .ghostty, .warp, .hyper, .kitty, .wezterm, .alacritty, .terminal]
        for t in order { if installedTerminals.contains(t) { return t } }
        return .terminal
    }

    private func getAppleScript(for terminal: Terminal, script: String) -> String {
        let s = script.replacingOccurrences(of: "\"", with: "\\\"")
        switch terminal {
        case .iterm:
            return "tell application \"iTerm\"\nactivate\nif (count of windows) = 0 then\ncreate window with default profile\nelse\ntell current window\ncreate tab with default profile\nend tell\nend if\ntell current session of current window\nwrite text \"\(s)\"\nend tell\nend tell"
        case .terminal:
            return "tell application \"Terminal\"\nactivate\ndo script \"\(s)\"\nend tell"
        case .hyper:
            return "tell application \"Hyper\"\nactivate\nend tell\ndelay 0.5\ntell application \"System Events\"\ntell process \"Hyper\"\nkeystroke \"\(s)\"\nkeystroke return\nend tell\nend tell"
        case .warp:
            return "tell application \"Warp\"\nactivate\nend tell\ndelay 0.3\ntell application \"System Events\"\ntell process \"Warp\"\nkeystroke \"\(s)\"\nkeystroke return\nend tell\nend tell"
        case .kitty:
            return "tell application \"kitty\"\nactivate\nend tell\ndelay 0.3\ntell application \"System Events\"\ntell process \"kitty\"\nkeystroke \"\(s)\"\nkeystroke return\nend tell\nend tell"
        case .wezterm:
            return "tell application \"WezTerm\"\nactivate\nend tell\ndelay 0.3\ntell application \"System Events\"\ntell process \"wezterm-gui\"\nkeystroke \"\(s)\"\nkeystroke return\nend tell\nend tell"
        case .ghostty:
            return "tell application \"Ghostty\"\nactivate\nend tell\ndelay 0.3\ntell application \"System Events\"\ntell process \"Ghostty\"\nkeystroke \"\(s)\"\nkeystroke return\nend tell\nend tell"
        case .alacritty:
            return "tell application \"Alacritty\"\nactivate\nend tell"
        }
    }
}
