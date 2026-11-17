#if os(macOS)
import Foundation
import Testing
@testable import PluginDevice

/// 回归 #1207：插件 boot 在主 actor 上同步读取并解码整份 CPU 历史缓存
/// （最多 43,200 点），阻塞 UI 配置。读取与解码必须离开主 actor，
/// boot 先以空历史运行，缓存就绪后合并发布。
@MainActor
@Suite("CPUHistoryService async restore")
struct CPUHistoryRestoreTests {

    @Test("boot returns with an empty history and restores the cache asynchronously")
    func bootRestoresCacheAsynchronously() async throws {
        let url = try makeHistoryFile(named: "restore", points: [
            CPUDataPoint(timestamp: Date().timeIntervalSince1970 - 60, usage: 25.0),
            CPUDataPoint(timestamp: Date().timeIntervalSince1970 - 30, usage: 75.0),
        ])
        let service = CPUHistoryService(storageFileURL: url)

        // Task.detached 不会同步完成，主 actor 未让出前恢复一定未落位：
        // boot 以空历史先返回（#1207）。
        #expect(service.longTermHistory.isEmpty)

        try await waitUntil("longTermHistory restored") { !service.longTermHistory.isEmpty }

        #expect(service.longTermHistory.map(\.usage) == [25.0, 75.0])
    }

    @Test("corrupt cache is quarantined and history stays empty")
    func corruptCacheIsQuarantined() async throws {
        let url = try makeCorruptHistoryFile(named: "corrupt")
        let service = CPUHistoryService(storageFileURL: url)
        #expect(service.longTermHistory.isEmpty)

        let quarantineURL = try #require(service.corruptStorageFileURL)
        try await waitUntil("quarantine file appears") {
            FileManager.default.fileExists(atPath: quarantineURL.path)
        }

        #expect(service.longTermHistory.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("restored cache merges with points recorded during the restore window")
    func restoredCacheMergesWithBootWindowPoints() throws {
        let service = CPUHistoryService(storageFileURL: try isolatedEmptyURL(named: "merge"))
        let diskPoints = [
            CPUDataPoint(timestamp: 1000, usage: 10.0),
            CPUDataPoint(timestamp: 2000, usage: 20.0),
        ]
        service.longTermHistory = [CPUDataPoint(timestamp: 3000, usage: 30.0)]

        service.applyLoadedHistory(diskPoints)

        // 磁盘数据在前、启动窗口的采样点保留在后，时间顺序不得被覆盖。
        #expect(service.longTermHistory.map(\.timestamp) == [1000, 2000, 3000])
    }

    @Test("saves are skipped while the cache is still restoring")
    func savesAreSkippedWhileRestoring() async throws {
        let url = try makeHistoryFile(named: "skip-save", points: [
            CPUDataPoint(timestamp: Date().timeIntervalSince1970 - 60, usage: 25.0),
            CPUDataPoint(timestamp: Date().timeIntervalSince1970 - 30, usage: 75.0),
        ])
        let service = CPUHistoryService(storageFileURL: url)

        // 主 actor 尚未让出：恢复一定未落位。此时结算 + 保存不得用
        // 只含启动窗口采样的缓冲覆盖磁盘缓存（#1207）。
        service.recordDataPoint(usage: 40.0)
        service.stopRecording()

        // 恢复未落位时保存必须被封锁（saveHistory 返回 nil）。
        #expect(service.saveHistory() == nil)

        // 结算点已让缓冲非空，必须等磁盘数据真正合并进来再断言。
        try await waitUntil("restore applied") { service.longTermHistory.map(\.usage).contains(25.0) }

        let dataOnDisk = try JSONDecoder().decode([CPUDataPoint].self, from: Data(contentsOf: url))
        #expect(dataOnDisk.map(\.usage) == [25.0, 75.0])

        #expect(service.longTermHistory.map(\.usage).first == 25.0)
        #expect(service.longTermHistory.map(\.usage).contains(40.0))
        #expect(service.longTermHistory.count == 3)
    }

    // MARK: - Helpers

    private func makeHistoryFile(named name: String, points: [CPUDataPoint]) throws -> URL {
        let url = try isolatedEmptyURL(named: name)
        try JSONEncoder().encode(points).write(to: url, options: .atomic)
        return url
    }

    private func makeCorruptHistoryFile(named name: String) throws -> URL {
        let url = try isolatedEmptyURL(named: name)
        try Data("this is not a history array".utf8).write(to: url, options: .atomic)
        return url
    }

    private func isolatedEmptyURL(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("device-history-restore-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("history.json")
    }

    private func waitUntil(
        _ label: String,
        timeout: TimeInterval = 5,
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                Issue.record("timeout waiting for \(label)")
                return
            }
            await Task.yield()
        }
    }
}
#endif
