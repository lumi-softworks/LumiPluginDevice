import AppKit
import Foundation
import Testing
@testable import PluginDevice

/// 进程图标按路径缓存回归测试（#1306）。
///
/// 修复前每一行 body 每次求值都调用 `NSWorkspace.icon(forFile:)`，
/// 榜单 1Hz 刷新时视口外的行也会反复解析；缓存后同一路径必须命中
/// 同一 `NSImage` 实例。
@Suite("ProcessMetricRow 图标缓存")
struct ProcessIconCacheTests {

    /// 造一个真实存在的临时文件，让 `icon(forFile:)` 有路径可解析。
    private func makeSampleFile() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProcessIconCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("sample.txt")
        try Data("x".utf8).write(to: file)
        return file
    }

    @Test("同一路径第二次读取命中缓存，返回同一实例")
    func samePathReturnsCachedInstance() throws {
        let file = try makeSampleFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let cache = ProcessMetricRow.ProcessIconCache()
        let first = cache.image(forPath: file.path)
        let second = cache.image(forPath: file.path)

        #expect(first === second, "同一路径必须命中缓存而不是重新解析")
    }

    @Test("不同路径各自解析出有效图标")
    func differentPathsResolveValidImages() throws {
        let fileA = try makeSampleFile()
        let fileB = try makeSampleFile()
        defer {
            try? FileManager.default.removeItem(at: fileA)
            try? FileManager.default.removeItem(at: fileB)
        }

        let cache = ProcessMetricRow.ProcessIconCache()
        let imageA = cache.image(forPath: fileA.path)
        let imageB = cache.image(forPath: fileB.path)

        #expect(imageA.size.width > 0)
        #expect(imageB.size.width > 0)
    }
}
