import AppKit
import UniformTypeIdentifiers

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
let fm = FileManager.default
let home = fm.homeDirectoryForCurrentUser
let bottles = home.appendingPathComponent("Library/Application Support/CrossOver/Bottles")
let support = home.appendingPathComponent("Library/Application Support/FH5 Preview Patch")
let resources = Bundle.main.resourceURL!

func message(_ title: String, _ detail: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = detail
    alert.runModal()
}

func choose(_ title: String, extension suffix: String, directory: URL? = nil) -> URL? {
    let panel = NSOpenPanel()
    panel.title = title
    panel.prompt = "选择"
    panel.directoryURL = directory
    if let type = UTType(filenameExtension: suffix) { panel.allowedContentTypes = [type] }
    return panel.runModal() == .OK ? panel.url : nil
}

func steamCandidates(_ bottle: URL) -> [URL] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = [resources.appendingPathComponent("find-steam.sh").path, bottle.path]
    let output = Pipe()
    task.standardOutput = output
    guard (try? task.run()) != nil else { return [] }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    return String(decoding: data, as: UTF8.self).split(separator: "\n")
        .map { URL(fileURLWithPath: String($0)) }
}

func run() throws {
    let available = ((try? fm.contentsOfDirectory(at: bottles, includingPropertiesForKeys: nil)) ?? [])
        .filter { fm.fileExists(atPath: $0.appendingPathComponent("cxbottle.conf").path) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    guard !available.isEmpty else {
        message("找不到 CrossOver 容器", "请先在 CrossOver Preview 中启用已安装 Steam 和《地平线 5》的容器。")
        return
    }

    let selector = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 30))
    selector.addItems(withTitles: available.map(\.lastPathComponent))
    if let saved = UserDefaults.standard.string(forKey: "Bottle"),
       let index = available.firstIndex(where: { $0.lastPathComponent == saved }) {
        selector.selectItem(at: index)
    } else if let index = available.firstIndex(where: { !steamCandidates($0).isEmpty }) {
        selector.selectItem(at: index)
    }
    let alert = NSAlert()
    alert.messageText = "地平线 5 · CrossOver Preview 补丁"
    alert.informativeText = "选择安装了 Steam 和《地平线 5》的容器。启动前请退出 Windows 版 Steam。"
    alert.accessoryView = selector
    alert.addButton(withTitle: "打补丁并启动")
    alert.addButton(withTitle: "取消")
    alert.addButton(withTitle: "恢复原始 DLL")
    let response = alert.runModal()
    guard response == .alertFirstButtonReturn || response == .alertThirdButtonReturn else { return }
    let bottle = available[selector.indexOfSelectedItem]
    UserDefaults.standard.set(bottle.lastPathComponent, forKey: "Bottle")

    var args = [resources.appendingPathComponent("patch.sh").path]
    if response == .alertThirdButtonReturn {
        args += ["restore", bottle.path]
    } else {
        let candidates = Array(Set(steamCandidates(bottle)))
        let steam: URL
        if candidates.count == 1 {
            steam = candidates[0]
        } else {
            guard let selected = choose("选择 Steam 安装目录里的 steam.exe", extension: "exe", directory: candidates.first?.deletingLastPathComponent()),
                  selected.lastPathComponent.lowercased() == "steam.exe" else { return }
            steam = selected
        }
        let defaultPreview = URL(fileURLWithPath: "/Applications/CrossOver Preview.app")
        let preview: URL
        if fm.fileExists(atPath: defaultPreview.path) {
            preview = defaultPreview
        } else {
            guard let selected = choose("选择 CrossOver Preview.app", extension: "app", directory: defaultPreview.deletingLastPathComponent()) else { return }
            preview = selected
        }
        args += ["launch", bottle.path, steam.path, preview.path]
    }

    try fm.createDirectory(at: support, withIntermediateDirectories: true)
    let log = support.appendingPathComponent("最近一次运行.log")
    try Data().write(to: log, options: .atomic)
    let handle = try FileHandle(forWritingTo: log)
    defer { try? handle.close() }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = args
    task.standardOutput = handle
    task.standardError = handle
    try task.run()
    let deadline = Date().addingTimeInterval(3)
    while task.isRunning && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    if !task.isRunning && task.terminationStatus != 0 {
        message("操作未完成", (try? String(contentsOf: log, encoding: .utf8)) ?? log.path)
    } else if response == .alertThirdButtonReturn {
        message("已恢复原始 DLL", bottle.lastPathComponent)
    }
}

do { try run() } catch { message("操作未完成", error.localizedDescription) }
