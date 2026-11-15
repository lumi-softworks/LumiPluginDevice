# Views

视图层：所有 SwiftUI 视图。命名约定：`*View.swift`。
菜单栏专用视图见 `MenuBar/` 子目录。

| 文件 | 职责 |
| --- | --- |
| `DeviceInfoView.swift` | 设备信息主视图（插件主内容，仪表盘组合与响应式布局） |
| `Dashboard/` | 仪表盘组件：英雄指标卡、健康诊断、趋势图、进程榜、电池/存储明细、卡片容器与环形/微型图表 |
| `DeviceInfoAboutView.swift` | 「关于」文档页 |
| `DeviceInfoManualView.swift` | 「说明书」文档页 |
| `TopProcessesView.swift` | 进程占用排行视图（进程榜与详情页共用行视图） |
| `MemoryHistoryGraphView.swift` / `MemoryHistoryDetailView.swift` | 内存历史图表与详情 |
| `CPUHistoryGraphView.swift` / `CPUHistoryDetailView.swift` | CPU 历史图表与详情（详情页含 CPU 温度趋势图） |
| `ThermalHistoryGraphView.swift` | CPU / die 温度历史图表（摄氏度 Y 轴，量程自适应） |
| `GPUHistoryGraphView.swift` / `GPUHistoryDetailView.swift` | GPU 历史图表与详情 |
| `DeviceHistoryChartGeometry.swift` | 历史图表共用的时间戳→坐标映射 |
