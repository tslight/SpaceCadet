import Foundation

enum LaunchAtLoginError: Error {
    case executableNotFound
}

enum LaunchAtLoginManager {
    private static let label = "com.apple.space-cadet.app"

    private static var agentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/LaunchAgents")
    }

    private static var plistURL: URL {
        agentsDir.appendingPathComponent("\(label).plist")
    }

    static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func set(enabled: Bool, executablePath: String?) throws {
        if enabled {
            guard let exec = executablePath, !exec.isEmpty else {
                throw LaunchAtLoginError.executableNotFound
            }
            try install(executablePath: exec)
        } else {
            try remove()
        }
    }

    private static func install(executablePath: String) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: agentsDir.path) {
            try fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        }
        let contents: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": true,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: contents, format: .xml, options: 0)
        try data.write(to: plistURL)

        // Try modern bootstrap; fall back to load
        let uid = getuid()
        let bootstrapStatus = run("/bin/launchctl", ["bootstrap", "gui/\(uid)", plistURL.path])
        if bootstrapStatus != 0 {
            _ = run("/bin/launchctl", ["load", plistURL.path])
        }
    }

    private static func remove() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            let uid = getuid()
            let bootoutStatus = run("/bin/launchctl", ["bootout", "gui/\(uid)", plistURL.path])
            if bootoutStatus != 0 {
                _ = run("/bin/launchctl", ["unload", plistURL.path])
            }
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    @discardableResult
    private static func run(_ launchPath: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        task.standardOutput = FileHandle.standardOutput
        task.standardError = FileHandle.standardError
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}
