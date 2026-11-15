# Support

支撑层：不归属 Model / Service / ViewModel / View 任一分类的辅助代码，
例如图表渲染、主题状态色与本地化辅助。

| 文件 | 职责 |
| --- | --- |
| `CPUMenuBarChartRenderer.swift` | CPU 菜单栏柱状图 NSImage 渲染 |
| `MemoryMenuBarChartRenderer.swift` | 内存菜单栏柱状图 NSImage 渲染 |
| `GPUMenuBarChartRenderer.swift` | GPU 菜单栏柱状图 NSImage 渲染 |
| `DeviceStatusColor.swift` | 指标状态分级与主题语义色映射 |
| `DashboardHealth.swift` | 仪表盘健康评分与逐项状态聚合（纯值类型） |
| `DashboardLayout.swift` | 仪表盘响应式断点 |
| `TrendScale.swift` | 趋势图 Y 轴量程与速率文本格式化 |
| `ThermalSensorLabel.swift` | 温度传感器行标签（可注入本地化解析） |
| `PluginLocalization.swift` | 插件作用域本地化服务 |
