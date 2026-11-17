#if os(macOS)
import Combine
import Foundation
import Testing
@testable import PluginDevice

@MainActor
@Suite("StorageService scan delivery")
struct StorageVolumesTests {

    @Test("each scan delivers its own round's external volumes")
    func eachScanDeliversCurrentRound() {
        let service = StorageService()
        service.startMonitoring()
        defer { service.stopMonitoring() }

        var deliveries: [[VolumeInfo]] = []
        var cancellable: AnyCancellable?
        cancellable = service.$externalVolumes.dropFirst().sink { deliveries.append($0) }

        service.scanVolumes()
        let afterFirst = service.externalVolumes
        service.scanVolumes()
        let afterSecond = service.externalVolumes
        _ = cancellable

        // 每次扫描必须把「本轮」的卷列表交给订阅方；
        // objectWillChange 在写入之前触发，读到的永远是上一轮（#793）。
        #expect(deliveries.count == 2)
        #expect(deliveries[0] == afterFirst)
        #expect(deliveries[1] == afterSecond)
    }

    @Test("subscription replays the current scan result once")
    func subscriptionReplaysCurrentVolumes() {
        let service = StorageService()
        service.startMonitoring()
        defer { service.stopMonitoring() }

        var replayed: [VolumeInfo]? = nil
        var cancellable: AnyCancellable?
        cancellable = service.$externalVolumes.sink { if replayed == nil { replayed = $0 } }
        _ = cancellable

        // 订阅即回放当前值：observer 无需再单独做一次初始 apply。
        #expect(replayed == service.externalVolumes)
    }
}
#endif
