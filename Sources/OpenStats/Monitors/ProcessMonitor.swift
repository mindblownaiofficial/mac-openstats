import Foundation

/// Lists the heaviest processes using `ps`, which is cheap enough to run every few seconds
/// and avoids private APIs.
final class ProcessMonitor {
    func sample(limit: Int = 5) -> (byCPU: [ProcessRow], byMemory: [ProcessRow]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return ([], []) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return ([], []) }

        var rows: [ProcessRow] = []
        for line in output.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = UInt64(parts[2]) else { continue }
            rows.append(ProcessRow(pid: pid, name: String(parts[3]), cpu: cpu, memory: rssKB * 1024))
        }
        let byCPU = Array(rows.sorted { $0.cpu > $1.cpu }.prefix(limit))
        let byMemory = Array(rows.sorted { $0.memory > $1.memory }.prefix(limit))
        return (byCPU, byMemory)
    }
}
