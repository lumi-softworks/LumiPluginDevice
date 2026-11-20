# TestPlan — PluginDevice

## 包概述

PluginDevice Lumi 的设备信息插件，提供系统资源监控（CPU / 内存 / GPU / 电池 / 存储）与历史趋势， 支持主内容视图、菜单栏图表、设置页与文档页等贡献点。

平台: macOS 14+, iOS 17+
测试文件: 19 个，用例总数: 96

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Services/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DevicePlugin`
- `BatteryPowerSource`
- `CPUTimeRange`
- `DeviceData`
- `DeviceHistoryRange`
- `DeviceHistorySample`
- `DeviceStatusScope`
- `GPUTimeRange`
- `MemoryTimeRange`
- `SystemMetrics`
- `VolumeInfo`
- `DeviceMetricsObserver`
- `MenuBarAppearanceObserver`
- `BatteryHistoryService`
- `BatteryService`
- `CPUHistoryService`
- `CPUService`
- `ThermalHistoryService`
- `ThermalDataPoint`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（9 条）：由 `onBootRegistersEntryContentViewAndDocs`、`onBootAppendsToExistingEntries`、`onBootNoOpsWithoutSettingView` 等用例锁定；改动该模块时优先跑对应测试文件。
- **温度历史**（3 条）：由 `recordsRecentPoints`、`filtersRecentByRange`、`usesLongTermBufferForLongerRanges` 等用例锁定；改动温度历史采集或时间范围语义时优先跑对应测试文件。
- **温度传感器**（5 条）：由 `privateSymbolsAvailable`、`sortedByIndex`、`readingsInRange` 等用例锁定；改动底层传感器读取时优先跑对应测试文件。
- **历史范围裁剪**（4 条）：由 `oneHourRangeUsesHighResolutionBuffer`、`fourHourRangeTrimsLongTermBuffer` 等用例锁定；改动历史时间范围语义或视图取数方式时优先跑对应测试文件。
- **历史图表几何**（8 条）：由 `xMapsTimestampsProportionally`、`longGapKeepsProportionalWidth`、`xClampsOutOfRangeTimestamps`、`hoverSelectsNearestTimestamp`、`singlePointAndZeroSpanReturnFirstIndex`、`tieBreaksToLowerIndex`、`duplicateTimestampsHitFirstOccurrence`、`binarySearchMatchesLinearReference` 锁定，防止绘线或悬浮选点退回数组等距映射，或二分查找破坏就近命中/平局语义（**#1206**）。
- **CPU 采样**（4 条）：由 `averageUsageAcrossCPUs`、`usageIsDeltaBased`、`shortBuffersReturnZero`、`zeroCPUCountReturnsZero` 锁定，防止 `host_processor_info` 返回的 CPU 数量/buffer 长度与循环不一致时越界。
- **本地化**（5 条）：由 `memoryMonitorHasTranslationsInCompiledBundle`、`sensorLabelUsesInjectedLocalization`、`sensorLabelHasTranslationsInCompiledBundle`、`registrationTitlesUseInjectedLocalization`、`entryLabelsHaveTranslationsInCompiledBundle` 锁定，防止视图词条与注册入口标题绕过 `pluginLocalization`，或在某个规范语言下缺失而回退成英文 key。
- **设备状态采集**（3 条）：由 `processesScopeMergesRankingsAndDedups`、`processesScopeCapsAtLimit`、`onDemandSamplingSeedsBaselineThenReturnsMetrics` 等用例锁定；改动 `DeviceStatusCollector` 进程榜单合并或 `ProcessService` 按需采样时优先跑对应测试文件。
- **进程行图标缓存**（2 条）：由 `samePathReturnsCachedInstance`、`differentPathsResolveValidImages` 锁定；改动 `ProcessMetricRow` 图标解析或详情列表渲染时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | onBoot 不再注册内存监控设置入口，但仍注册主内容与文档 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersEntryContentViewAndDocs` |
| 2 | 综合 | onBoot 追加语义不覆盖已有入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootAppendsToExistingEntries` |
| 3 | 综合 | 设置视图未注册时 onBoot 优雅降级 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootNoOpsWithoutSettingView` |
| 4 | 综合 | 插件可经 kernel.start 启动并注册入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startViaKernelBootsPlugin` |
| 5 | 综合 | ActivityBar 激活设备入口时切换主内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activityBarActivationSetsContentView` |
| 6 | 综合 | DeviceData 采集静态系统信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deviceDataStaticInfo` |
| 7 | 综合 | DeviceData 动态指标可刷新且非负 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deviceDataDynamicMetrics` |
| 8 | 综合 | DeviceInfoAboutView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `aboutViewRenders` |
| 9 | 综合 | DeviceInfoManualView 可渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `manualViewRenders` |
| 10 | 温度历史 | 温度采样点写入高频缓冲 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordsRecentPoints` |
| 11 | 温度历史 | 1 小时范围只保留截止时间之后的点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `filtersRecentByRange` |
| 12 | 温度历史 | 超过 1 小时的范围走分钟级聚合缓冲 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesLongTermBufferForLongerRanges` |
| 13 | 温度传感器 | 私有 HID 符号仍可解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `privateSymbolsAvailable` |
| 14 | 温度传感器 | 读数按传感器下标升序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sortedByIndex` |
| 15 | 温度传感器 | 读数处于物理合理区间 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `readingsInRange` |
| 16 | 温度传感器 | 峰值等于同批次最大值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `peakIsMaximum` |
| 17 | 温度传感器 | 可用性与非空读数一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `availabilityMatchesRead` |
| 18 | 历史范围裁剪 | 1 小时范围取高频缓冲并截断过期样本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oneHourRangeUsesHighResolutionBuffer` |
| 19 | 历史范围裁剪 | 4 小时范围截断超出范围的长期样本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fourHourRangeTrimsLongTermBuffer` |
| 20 | 历史范围裁剪 | 24 小时与 30 天范围返回不同的数据量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `differentLongRangesReturnDifferentData` |
| 21 | 历史范围裁剪 | 内存历史同样按范围截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `memoryHistoryTrimsByRange` |
| 22 | CPU 进程监控 | Apple Silicon 24MHz ticks 下占满单核为 100% | 注入 timebase 125/3 | 计算 CPU 百分比 | 结果为 100 | P1 | ✅ 已覆盖 | `appleSiliconTimebaseYieldsOneHundredPercent` |
| 23 | CPU 进程监控 | Intel 1GHz ticks 下占满单核为 100% | 注入 timebase 1/1 | 计算 CPU 百分比 | 结果为 100 | P1 | ✅ 已覆盖 | `intelTimebaseYieldsOneHundredPercent` |
| 24 | CPU 进程监控 | 多线程进程可以超过 100% | 注入 timebase 125/3，1 秒内 2 核 ticks | 计算 CPU 百分比 | 结果为 200 | P1 | ✅ 已覆盖 | `multiCoreUsageExceedsOneHundredPercent` |
| 25 | CPU 进程监控 | 零采样间隔返回 0 | 注入 elapsed=0 | 计算 CPU 百分比 | 结果为 0 | P2 | ✅ 已覆盖 | `zeroElapsedReturnsZero` |
| 26 | 综合 | 禁用自动撤回，重新启用恢复菜单栏贡献 | 真实 kernel 启停插件 | 禁用/启用插件 | 禁用后贡献为空，启用后恢复 CPU 与内存弹窗贡献 | P1 | ✅ 已覆盖 | `disableAndEnableRestoresMenuBarContributions` |
| 27 | CPU 进程监控 | 直接展示真实 CPU 占用，不按前 N 名归一化 | 构造 0.6% / 12.4% / 120% 的进程指标 | 读取展示文案 | 分别显示 1% / 12% / 120% | P1 | ✅ 已覆盖 | `displaysRealCPUUsageWithoutNormalization` |
| 28 | CPU 进程监控 | 进度条以单核 100% 为满格且不超过 100% | 构造 50% / 120% / -5% 的进程指标 | 读取进度条比例 | 分别得到 0.5 / 1 / 0 | P2 | ✅ 已覆盖 | `barFractionIsCappedAtOneHundredPercent` |
| 29 | CPU 进程监控 | 同名多进程合并为一条并标注份数，本应用组单独标记 | 2 个同名 Chrome Helper + PID 为自身的 Lumi | 执行聚合 | Chrome 一条且份数 2、CPU 相加；Lumi 标记为本应用 | P1 | ✅ 已覆盖 | `aggregatesSameNameProcessesAndMarksSelf` |
| 30 | CPU 进程监控 | 不同完整名称的进程不会被误合并 | WebKit WebContent / Networking 两条采样 | 执行聚合 | 保持两条独立记录，份数均为 1 | P1 | ✅ 已覆盖 | `keepsDistinctNamesSeparate` |
| 31 | CPU 进程监控 | 主弹窗只展示前 5 条，完整列表保留 | 7 条进程指标 | 读取预览与完整列表 | 预览 5 条，完整列表 7 条 | P2 | ✅ 已覆盖 | `previewLimitsToFive` |
| 32 | CPU 进程监控 | CPU 采样间隔与网络区块统一为 1 秒 | 读取采样间隔常量 | 断言常量 | 等于 1.0 | P1 | ✅ 已覆盖 | `samplingIntervalMatchesNetworkBlock` |
| 33 | 历史图表几何 | X 坐标按时间戳比例映射 | 时间戳 0 / 3600 / 7200，宽 200 | 调用 `DeviceHistoryChartGeometry.x` | 分别为 0 / 100 / 200 | P1 | ✅ 已覆盖 | `xMapsTimestampsProportionally` |
| 34 | 历史图表几何 | 长时间空洞占据真实水平距离 | 时间戳 0 / 60 / 3660，宽 100 | 计算 60s 的 X 坐标 | 约 1.639，而非等距的 50 | P1 | ✅ 已覆盖 | `longGapKeepsProportionalWidth` |
| 35 | 历史图表几何 | 超出时间范围的值被钳制在边界 | 时间范围 0...100，宽 50 | 传入 -10 / 200 / 起止相同 | 分别为 0 / 50 / 0 | P1 | ✅ 已覆盖 | `xClampsOutOfRangeTimestamps` |
| 36 | 历史图表几何 | 悬浮选点按时间轴就近命中 | 时间戳 0 / 60 / 3660，宽 100 | 传入 x=1.639 / 50 / 99 / 0 / 空数组 | 命中下标 1 / 1 / 2 / 0 / nil | P1 | ✅ 已覆盖 | `hoverSelectsNearestTimestamp` |
| 37 | 历史图表几何 | 单点与零跨度时间轴直接命中第一个点 | — | 传入单点数组与全等时间戳数组 | 返回下标 0，数组版与样本版一致 | P1 | ✅ 已覆盖 | `singlePointAndZeroSpanReturnFirstIndex` |
| 38 | 历史图表几何 | 距离相同的平局取更小下标 | — | 传入两点/三点时间轴的中点横坐标 | 平局命中更小下标，与线性扫描语义一致 | P1 | ✅ 已覆盖 | `tieBreaksToLowerIndex` |
| 39 | 历史图表几何 | 目标落在重复时间戳上时命中首个重复点 | — | 传入重复时间戳 60 三次的数组 | 命中首个重复下标 1 | P1 | ✅ 已覆盖 | `duplicateTimestampsHitFirstOccurrence` |
| 40 | 历史图表几何 | 二分查找与线性扫描基准在全宽度上等价 | 固定种子随机升序时间轴（400 点含空洞） | 全宽度 0.5 步长 + 500 个随机横坐标逐一比对 | 数组版与样本版都与线性基准一致（**回归 #1206**） | P0 | ✅ 已覆盖 | `binarySearchMatchesLinearReference` |
| 41 | CPU 采样 | 两个 CPU 各半负载时返回平均使用率 | 2 个 CPU 的完整状态数组 | 调用 `cpuUsage` | 返回 0.5 | P1 | ✅ 已覆盖 | `averageUsageAcrossCPUs` |
| 42 | CPU 采样 | 差分基于历史采样而不是绝对值 | 当前/历史状态均非零 | 调用 `cpuUsage` | 按两次采样的增量返回 0.35 | P1 | ✅ 已覆盖 | `usageIsDeltaBased` |
| 43 | CPU 采样 | buffer 长度不足 CPU 数量所需时返回 0 且不越界 | 数组长度小于 `cpuCount * CPU_STATE_MAX` | 以更大的 CPU 数量/长度调用 | 返回 0，不读取越界内存 | P0 | ✅ 已覆盖 | `shortBuffersReturnZero` |
| 44 | CPU 采样 | CPU 数量为 0 时返回 0 | `cpuCount = 0` | 调用 `cpuUsage` | 返回 0 | P2 | ✅ 已覆盖 | `zeroCPUCountReturnsZero` |
| 45 | 本地化 | Memory Monitor 在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 下均有译文 | 编译后的资源包 | 读取各语言 `Localizable.strings` | 五种语言都返回对应译文，不回退成英文 key（**回归** #902） | P1 | ✅ 已覆盖 | `memoryMonitorHasTranslationsInCompiledBundle` |
| 46 | 本地化 | 传感器行标签经注入的本地化解析并保留下标 | 注入 marker 解析器 | 调用 `ThermalSensorLabel.text(index: 3, resolve:)` | 得到 `localized:Sensor 3`，证明不再写死英文字面量（**回归** #901） | P1 | ✅ 已覆盖 | `sensorLabelUsesInjectedLocalization` |
| 47 | 本地化 | Sensor %d 在编译产物中已有译文 | 编译后的资源包 | 读取 en / zh-Hans / zh-HK / zh-TW 的 `Localizable.strings` | 各语言都返回对应译文（**回归** #901） | P1 | ✅ 已覆盖 | `sensorLabelHasTranslationsInCompiledBundle` |
| 48 | 本地化 | 文档、活动栏与菜单标题经过本地化解析 | 注入 marker 解析器，真实 kernel 启动并启用插件 | 读取文档入口、ActivityBar 入口与菜单栏贡献标题 | 全部为 `localized:Device Info` / `localized:Memory`，证明注册链不再写死中文字面量（**回归** #900） | P1 | ✅ 已覆盖 | `registrationTitlesUseInjectedLocalization` |
| 49 | 本地化 | Device Info 与 Memory 词条在所有规范语言下都有译文 | 编译后的资源包 | 读取 en / zh-Hans / zh-Hant / zh-HK / zh-TW 的 `Localizable.strings` | 五种语言都有对应译文，不回退成英文 key（**回归** #900） | P1 | ✅ 已覆盖 | `entryLabelsHaveTranslationsInCompiledBundle` |

| 50 | 设备状态卡片 | 载荷能通过 content 往返 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `payloadRoundTripsThroughContent` |
| 51 | 设备状态卡片 | 消息被标记为设备状态时间线事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageIsMarkedAsTimelineEvent` |
| 52 | 设备状态卡片 | 卡片被排除在 LLM 上下文之外 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cardIsExcludedFromLLMContext` |
| 53 | 设备状态卡片 | 损坏的 content 降级为 nil 而不是崩溃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `corruptedContentDegradesToNil` |
| 54 | 设备状态卡片 | 摘要文本对每个范围都可读 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summaryTextStaysReadable` |
| 55 | 设备状态卡片 | 会话与回合 ID 被写进消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageCarriesConversationAndTurn` |
| 56 | 设备状态卡片 | scope 缺失时回退到总览 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingScopeFallsBackToOverview` |
| 57 | 设备状态卡片 | scope 为空串时回退到总览 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `blankScopeFallsBackToOverview` |
| 58 | 设备状态卡片 | 合法 scope 被正确解析，且忽略大小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validScopeIsParsed` |
| 59 | 设备状态卡片 | 非法 scope 抛出工具执行错误 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidScopeThrows` |
| 60 | 设备状态卡片 | 宽松解析在非法值时返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `lenientScopeReturnsNilForInvalidValue` |
| 61 | 设备状态卡片 | 工具名固定为 device_status | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolNameIsStable` |
| 62 | 设备状态卡片 | input schema 声明了全部合法 scope | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inputSchemaDeclaresAllScopes` |
| 63 | 设备状态卡片 | 工具是低风险只读操作 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolIsLowRisk` |
| 64 | 设备状态卡片 | 渲染器优先级高于核心系统消息渲染器 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rendererOutranksCoreSystemMessage` |
| 65 | 设备状态卡片 | 渲染器只认设备状态卡片消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rendererOnlyHandlesDeviceStatusMessages` |
| 66 | 设备状态卡片 | 渲染器 ID 与时间线消息一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `rendererIDMatchesTimeline` |
| 67 | 设备状态卡片 | 摘要文本包含各指标的关键数值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryIncludesKeyMetrics` |
| 68 | 设备状态卡片 | 摘要在无数据时不编造指标 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryOmitsAbsentMetrics` |
| 69 | 设备状态卡片 | 温度无读数时摘要如实说明 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `summaryReportsMissingThermalReadings` |
| 70 | 设备状态卡片 | 字节格式化不会溢出 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `byteFormattingHandlesExtremeValues` |
| 71 | 设备状态卡片 | onBoot 注册 device_status 工具与卡片渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersToolAndRenderer` |
| 72 | 设备状态卡片 | 重复 onBoot 不会重复注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedBootDoesNotDuplicateRegistrations` |
| 73 | 设备状态卡片 | onDisable 撤回工具与渲染器 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `onDisableUnregistersToolAndRenderer` |
| 74 | 设备状态卡片 | onShutdown 撤回工具与渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onShutdownUnregistersToolAndRenderer` |
| 75 | 设备状态卡片 | 禁用后重新启用会恢复工具与渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onEnableRestoresToolAndRenderer` |
| 76 | 设备状态卡片 | 缺少工具与渲染器 Provider 时优雅降级 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `onBootDegradesWithoutProviders` |
| 77 | CPU 采样快照 | 每个 1Hz CPU 采样 tick 不得发布多个原子快照（**回归 #1210**） | 独立 CPUService 实例 | 驱动 3 个采样 tick 并收集快照发布 | 恰好 3 个快照，字段与旧属性一致 | P0 | ✅ 已覆盖 | `samplingTickPublishesExactlyOneAtomicSnapshot` |
| 78 | CPU 采样快照 | 历史记录边界每快照只写一个点并刷新一次 UI（**回归 #1210**） | 受控快照发布器 | 发送 3 个快照 | 记录/应用/菜单栏各恰好 3 次 | P0 | ✅ 已覆盖 | `cpuRecordingWritesOneHistoryPointPerSnapshot` |
| 79 | CPU 采样快照 | 快照字段保持原子一致 | 受控快照发布器 | 发送 1 个快照 | 应用侧收到完全相同的快照值 | P1 | ✅ 已覆盖 | `cpuRecordingKeepsSnapshotFieldsAtomic` |
| 80 | 历史视图模型 | recent-only 更新不得重复发布长期缓冲（**回归 #1209**） | 已有长期缓冲 | 两次 applyRecent | longTermHistory 发布数为 0 | P0 | ✅ 已覆盖 | `recentOnlyUpdateDoesNotRepublishLongTermHistory` |
| 81 | 历史视图模型 | 长期缓冲更新后发布并失效长期范围缓存（**回归 #1209**） | 已缓存 30 天结果 | applyLongTerm 追加一个点 | 发布 1 次且 30 天结果反映新点 | P1 | ✅ 已覆盖 | `longTermUpdateRepublishesAndInvalidatesLongRangeCache` |
| 82 | 历史视图模型 | 高频缓冲更新后失效小时范围缓存（**回归 #1209**） | 已缓存 1 小时结果 | applyRecent 追加一个点 | 1 小时结果反映新点 | P1 | ✅ 已覆盖 | `recentUpdateInvalidatesHighResolutionCache` |
| 83 | 内存统计 | 概览内存必须计入压缩内存页（**回归 #649**） | 构造 vm_statistics64 | 注入非零 compressor_page_count | used = active + wired + compressed | P0 | ✅ 已覆盖 | `usedMemoryIncludesCompressorPages` |
| 84 | 内存统计 | 无压缩页时 used 为 active 与 wired 之和 | 构造 vm_statistics64 | compressor_page_count = 0 | used = active + wired | P2 | ✅ 已覆盖 | `usedMemoryWithoutCompressorPages` |
| 85 | 内存统计 | 概览实时路径与弹窗 MemoryService 同 flavor | 真实 host_statistics64 调用 | 调用 currentMemoryUsage | used 在 (0, total] 内且 total 为物理内存 | P1 | ✅ 已覆盖 | `liveMemoryUsageIsSane` |
| 86 | 存储卷交付 | 每次扫描必须交付本轮外置卷列表（**回归 #793**） | 独立 StorageService 实例 | 订阅 $externalVolumes 后连续两次 scanVolumes | 两次交付且值与本轮属性一致 | P0 | ✅ 已覆盖 | `eachScanDeliversCurrentRound` |
| 87 | 存储卷交付 | 订阅即回放当前扫描结果 | 独立 StorageService 实例 | 订阅 $externalVolumes 取首值 | 首个交付等于当前 externalVolumes | P1 | ✅ 已覆盖 | `subscriptionReplaysCurrentVolumes` |
| 88 | CPU 历史恢复 | boot 必须以空历史先返回，磁盘缓存随后异步恢复（**回归 #1207**） | 带两点的缓存文件 | 构造 CPUHistoryService 并等待恢复 | init 返回时缓冲为空，恢复后与磁盘数组一致 | P0 | ✅ 已覆盖 | `bootRestoresCacheAsynchronously` |
| 89 | CPU 历史恢复 | 损坏缓存被隔离且历史保持为空 | 写入非法 JSON 的缓存文件 | 构造 CPUHistoryService 并等待隔离 | 隔离文件出现、源文件移除、缓冲为空 | P0 | ✅ 已覆盖 | `corruptCacheIsQuarantined` |
| 90 | CPU 历史恢复 | 恢复的磁盘数据必须与启动窗口的采样点合并，不得覆盖 | 独立服务实例 | 先写入启动窗口的点再 applyLoadedHistory | 时间顺序为磁盘数据在前、启动点在后 | P1 | ✅ 已覆盖 | `restoredCacheMergesWithBootWindowPoints` |
| 91 | CPU 历史恢复 | 恢复完成前保存必须被封锁，不得用空缓冲覆盖缓存 | 带两点的缓存文件 | 恢复落位前结算并保存 | saveHistory 返回 nil，磁盘文件未被覆盖，恢复后三点齐全 | P0 | ✅ 已覆盖 | `savesAreSkippedWhileRestoring` |
| 92 | 设备状态采集 | processes 范围合并 CPU 榜与内存榜并去重，按 CPU 优先排序 | 预置 topProcesses 四条指标 | 调用 `collect(scope: .processes)` | 去重无重复、CPU 优先排序、字段一致（**#1293**） | P1 | ✅ 已覆盖 | `processesScopeMergesRankingsAndDedups` |
| 93 | 设备状态采集 | 榜单超过上限时只保留前 processLimit 条 | 预置 20 条指标 | 调用 `collect(scope: .processes)` | 恰好 8 条且顺序正确 | P1 | ✅ 已覆盖 | `processesScopeCapsAtLimit` |
| 94 | 设备状态采集 | 按需采样第一轮播种基线，第二轮返回真实进程 | 独立 ProcessService 实例 | 连续两次 `sampleProcessesOnce()` | 首轮为空、次轮非空且进程名非空（**#1293**） | P0 | ✅ 已覆盖 | `onDemandSamplingSeedsBaselineThenReturnsMetrics` |
| 95 | 进程行图标缓存 | 同一路径第二次读取命中缓存，返回同一实例 | 临时文件路径 | 连续两次 `image(forPath:)` | 两次返回同一 `NSImage` 实例（**#1306**） | P1 | ✅ 已覆盖 | `samePathReturnsCachedInstance` |
| 96 | 进程行图标缓存 | 不同路径各自解析出有效图标 | 两个临时文件路径 | 分别调用 `image(forPath:)` | 两次都得到宽度大于 0 的图标 | P2 | ✅ 已覆盖 | `differentPathsResolveValidImages` |

> 说明：全部 **96 条场景**已在本包 `swift test` 中实跑通过。
>
> 变异验证（#1293）：M8 删除 `sampleProcessesOnce()` 的基线回写 → `onDemandSamplingSeedsBaselineThenReturnsMetrics` 转红（次轮拿不到可比对数据，返回空）。变异确认转红后还原，最终 90 条全绿。
> 变异验证（#1306）：M9 把 `ProcessIconCache.image(forPath:)` 改为直接调用 `NSWorkspace.icon(forFile:)` → `samePathReturnsCachedInstance` 转红（两次调用返回不同实例）。变异确认转红后还原，最终 92 条全绿。详情列表的 `VStack` → `LazyVStack` 属渲染层改动，无单元断言，靠源码审查锁定。
> 变异验证（#1206）：M10 平局比较 `<=` 改 `<` → `tieBreaksToLowerIndex` 转红（3 处平局断言，等价性测试不受影响）；M11 收敛后无条件返回 low → `binarySearchMatchesLinearReference`（数组版与样本版）、`hoverSelectsNearestTimestamp`、`duplicateTimestampsHitFirstOccurrence` 转红。变异均单独施加并确认转红后还原（cmp 字节一致），最终 96 条全绿。CPUHistoryGraphView 的悬浮层拆分（hover 状态移入子视图）属渲染层改动，无单元断言，靠源码审查锁定。
>
> 变异验证（#1210/#1209）：M1 删除 CPUService 采样完成块的原子 `usageSnapshot` 赋值 → `samplingTickPublishesExactlyOneAtomicSnapshot` 转红（快照数为 0）；M2 交换 `applyRecent`/`applyLongTerm` 的缓存失效谓词 → `recentUpdateInvalidatesHighResolutionCache`、`longTermUpdateRepublishesAndInvalidatesLongRangeCache` 转红（缓存未失效返回旧结果）；M3 在 `applyRecent` 中追加 `longTermHistory = longTermHistory` 模拟 combineLatest → `recentOnlyUpdateDoesNotRepublishLongTermHistory` 转红（发布数 2）。
> 变异验证（#649/#793）：M4 删除 `usedMemoryBytes` 的 compressed 项 → `usedMemoryIncludesCompressorPages` 转红；M5 删除 `scanVolumes` 的 `externalVolumes` 赋值 → `eachScanDeliversCurrentRound` 转红（交付数 0）。
> 变异验证（#1207）：M6 `applyLoadedHistory` 改为直接覆盖 → `restoredCacheMergesWithBootWindowPoints`、`savesAreSkippedWhileRestoring` 转红（启动窗口点丢失）；M7 删除 `saveHistory` 的恢复期封锁 → `savesAreSkippedWhileRestoring` 转红（封锁断言 saveHistory == nil 失败）。以上变异均单独施加并确认转红后还原，最终全量 `swift test` 全绿（86 用例）。
> #792 的匹配键修复以运行时取证验证：数字键字典返回 165 个事件服务，命名键 `PrimaryUsagePage`/`PrimaryUsage` 返回 57 个温度服务，修复后传感器下标 0...56（与 issue 审计机的预期一致）。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 19 / 19
- P1: 已覆盖 57 / 57
- P2: 已覆盖 20 / 20
- **合计: 96 / 96**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（19 条）
- **P1**: 其余功能性用例（57 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（20 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 96 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDevice
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
