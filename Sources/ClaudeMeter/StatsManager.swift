import Foundation
import Combine

class StatsManager: ObservableObject {
    @Published var rateLimitPct: Double?
    @Published var rateLimitResetsAt: Date?
    @Published var weeklyPct: Double?
    @Published var weeklyResetsAt: Date?
    /// 최초 로딩 중 여부 (한 번 완료되면 다시 true로 되지 않음)
    @Published var isLoadingUsage: Bool = true
    @Published var lastUpdated: Date?

    private var refreshTimer: Timer?
    private var isFetchingRateLimit = false

    init() {
        startPeriodicRefresh()
        fetchRateLimit()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        fetchRateLimit()
    }

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.fetchRateLimit()
        }
    }

    // MARK: - Rate Limit (claude /usage via PTY)

    private static let usageHelperScript = """
#!/usr/bin/env python3
import pty, os, time, select, re, json, sys, shutil

CLAUDE = shutil.which('claude') or '/opt/homebrew/bin/claude'

def drain(fd, secs):
    buf = b''
    end = time.time() + secs
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.3)
        if r:
            try: buf += os.read(fd, 8192)
            except OSError: break
    return buf

def run():
    master, slave = pty.openpty()
    env = os.environ.copy()
    env.pop('CLAUDECODE', None)
    import termios, struct, fcntl
    ws = struct.pack('HHHH', 50, 220, 0, 0)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, ws)
    pid = os.fork()
    if pid == 0:
        os.setsid()
        os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
        os.close(master); os.close(slave)
        os.execve(CLAUDE, [CLAUDE], env)
        os._exit(1)
    os.close(slave)
    buf = drain(master, 8)
    os.write(master, b'/usage')
    buf += drain(master, 1.5)
    os.write(master, b'\\r')
    buf += drain(master, 4)
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    os.close(master)
    return buf

def parse(buf):
    ansi = re.compile(r'\\x1b(?:\\[[0-9;?]*[A-Za-z]|\\][^\\x07]*\\x07|[^[\\]])')
    text = ansi.sub('', buf.decode('utf-8', errors='replace')).replace('\\r', '')
    text = re.sub(r'[\\u2580-\\u259F\\u2600-\\u26FF\\u2588-\\u258F]+', ' ', text)
    text = re.sub(r'\\s+', ' ', text)
    # All "XX% used" occurrences: [0]=session, [1]=weekly
    pcts = re.findall(r'(\\d+)\\s*%\\s*used', text)
    pct        = int(pcts[0]) / 100.0 if len(pcts) > 0 else None
    weekly_pct = int(pcts[1]) / 100.0 if len(pcts) > 1 else None
    # All reset times: [0]=session, [1]=weekly
    resets = re.findall(r'[Rr]e[a-z]*\\s*(\\d{1,2}(?::\\d{2})?)\\s*(am|pm|AM|PM)', text)
    resets_str        = (resets[0][0] + resets[0][1].lower()) if len(resets) > 0 else None
    weekly_resets_str = (resets[1][0] + resets[1][1].lower()) if len(resets) > 1 else None
    return pct, resets_str, weekly_pct, weekly_resets_str

if __name__ == '__main__':
    try:
        buf = run()
        pct, resets_str, weekly_pct, weekly_resets_str = parse(buf)
        result = {}
        if pct is not None:
            result['pct'] = pct
        if resets_str:
            result['resetsStr'] = resets_str
        if weekly_pct is not None:
            result['weeklyPct'] = weekly_pct
        if weekly_resets_str:
            result['weeklyResetsStr'] = weekly_resets_str
        print(json.dumps(result))
    except Exception as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr)
        sys.exit(1)
"""

    func fetchRateLimit() {
        guard !isFetchingRateLimit else { return }
        isFetchingRateLimit = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer {
                DispatchQueue.main.async {
                    self?.isFetchingRateLimit = false
                    self?.isLoadingUsage = false
                }
            }

            let scriptPath = NSTemporaryDirectory() + "claude_usage_helper.py"
            try? StatsManager.usageHelperScript.write(
                toFile: scriptPath, atomically: true, encoding: .utf8)

            let python3 = self?.findExecutable("python3") ?? "/usr/bin/python3"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: python3)
            process.arguments = [scriptPath]

            var env = ProcessInfo.processInfo.environment
            env.removeValue(forKey: "CLAUDECODE")
            process.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError  = errPipe

            guard (try? process.run()) != nil else { return }
            process.waitUntilExit()

            let data = outPipe.fileHandleForReading.readDataToEndOfFile()

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawPct = json["pct"] as? Double
            else { return }

            let resetsDate      = (json["resetsStr"]        as? String).flatMap { self?.parseResetTimeString($0) }
            let weeklyRawPct    = json["weeklyPct"]          as? Double
            let weeklyResetsDate = (json["weeklyResetsStr"] as? String).flatMap { self?.parseResetTimeString($0) }

            DispatchQueue.main.async {
                self?.rateLimitPct    = rawPct
                self?.rateLimitResetsAt = resetsDate
                self?.weeklyPct       = weeklyRawPct
                self?.weeklyResetsAt  = weeklyResetsDate
                self?.lastUpdated     = Date()
            }
        }
    }

    private func parseResetTimeString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let now = Date()
        let cal = Calendar.current

        for fmt in ["h:mma", "ha"] {
            formatter.dateFormat = fmt
            if let timeOnly = formatter.date(from: str) {
                var comps = cal.dateComponents([.year, .month, .day], from: now)
                let t = cal.dateComponents([.hour, .minute], from: timeOnly)
                comps.hour = t.hour; comps.minute = t.minute; comps.second = 0
                if let candidate = cal.date(from: comps) {
                    return candidate > now ? candidate
                        : cal.date(byAdding: .day, value: 1, to: candidate)
                }
            }
        }
        return nil
    }

    private func findExecutable(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }
}
