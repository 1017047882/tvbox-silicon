# iPhone / iOS 15 兼容性核对

[Raven] 本次目标为 iPhone arm64、最低 iOS 15.0：检查源码和部署配置，替换旧系统不可用的接口，再通过云端 Apple 编译器检查。当前完成的是源码兼容修改及本地静态验证，尚未确认完整应用可以安装或运行。

用户设备系统为 iOS 15.5，属于当前 iOS 15.0 最低版本的覆盖范围，不需要提高部署版本。Perception 1.6.0 的最低 iOS 版本为 13，NavigationBackport 0.9.0 为 14；这两项依赖的部署要求均不排除 15.5。设备系统版本与编译器版本是两回事，仍需现代 Xcode 编译。

再次复查时将正则兼容层的首匹配查询改用 `NSRegularExpression.firstMatch`，避免在大型文本中收集全部匹配后才取第一项。补充首项选择、Unicode 子串索引、无匹配、空匹配和可选捕获的 Swift 回归用例；尚未在 Apple 环境执行，不声明性能实测结果。

[Nova] 修改范围与替代方式：

| 范围 | 发现的问题 | iOS 15 处理 |
| --- | --- | --- |
| 状态刷新 | 原生 Observation 需要 iOS 17 | 使用 Perception 1.6.0，添加视图追踪；其依赖自带对象环境注入兼容接口 |
| 页面导航 | NavigationStack / NavigationPath 需要 iOS 16 | 使用 NavigationBackport 0.9.0，并补充可选对象导航 |
| 时间与同步 | Duration、ContinuousClock、OSAllocatedUnfairLock 需要 iOS 16 | 使用纳秒异步休眠、单调时钟和 NSLock；保留取消传播与并发互斥 |
| URL、正则 | 新版 URL 方法及 Swift Regex 运行时 | 使用旧版 Foundation URL、URLComponents、NSRegularExpression，保留查询参数和 Unicode 索引 |
| 自适应布局 | Layout、Grid、ViewThatFits 等需要 iOS 16 | 新系统保留原布局，旧系统使用堆栈、LazyVGrid 和最小高度布局 |
| 照片与分享 | PhotosPicker、Transferable、ShareLink 需要 iOS 16 | 使用 PHPickerViewController、临时文件复制和 UIActivityViewController |
| 空状态与表单 | ContentUnavailableView、LabeledContent 需要 iOS 16/17 | 保留提示、标签和值、操作按钮 |
| 滚动、展示与装饰 | 新版滚动定位、弹层配置、动画与符号效果 | 用 ScrollViewReader、旧版 onChange、基础动画和触觉反馈；专属装饰按版本启用 |
| 播放与缩略图 | 新版图片生成与旋转接口 | 使用旧版异步图片生成，旋转接口按版本选择 |
| HDR 转换 | iOS 16 的 VideoToolbox 像素传输 | 版本保护；iOS 15 使用现有软件色调映射路径 |
| 轮播单元格 | UIHostingConfiguration 需要 iOS 16 | 使用 UIHostingController，保留轮播和分页 |
| 未来 SDK | iOS 26/27 新符号不能由旧 SDK 编译 | 增加编译条件；27 接口默认关闭，旧系统执行替代分支 |

受 `#available` 和条件编译保护的新版代码可以保留；不能仅根据搜索到“iOS 17”或新版 API 名称就判断工程不兼容。

旧系统行为存在差异：弹层使用标准系统尺寸；部分动画、视差、滚动装饰没有对应效果；通用滚动定位兼容层支持程序主动定位，但不回写用户手动滚动的位置。首页轮播另用分页 TabView 保留手势切页与选中项更新。iOS 15 的旋转需重点验证：公开的旧接口会请求系统重新评估方向，不能保证与 iOS 16 的几何更新请求完全一致。

[Pulse] 验证与交付边界：

- 本地 10 项 Python 构建准备检查通过。
- GitHub Actions YAML 可解析，10 个 Bash 步骤通过 `bash -n`。
- `git diff --check` 通过；源码条件与括号平衡检查覆盖 iOS 生效分支。
- 第三方 Swift 语法解析器在部分文件崩溃，不能代替 Apple Swift 编译器，也不作为编译成功证据。
- 已添加正则、URL、延迟取消、时钟、并发锁、HLS 属性及字幕标签的 Swift 行为测试；本机没有 Xcode，尚未执行这些测试。
- 工作流 `.github/workflows/build-ios15.yml` 增加完整 App Swift 源码的 `arm64-apple-ios15.0` 编译步骤。核心与 App 两步都通过才算源代码编译检查通过。
- App 检查使用 `Packages/IOS15AppCheck`，不链接应用运行时、不签名、不打包 IPA。JVM/Python/Node 等二进制的最低系统版本、最终链接与安装仍需单独验证。

可测性：时间格式化、正则捕获、HLS 与字幕解析适合纯函数测试；延迟校验应覆盖负值、非有限值、超限、有效值和任务取消，锁需要并发回归。上述条件可作为 MC/DC 用例设计输入；尚未测量覆盖率，不声明达到任何覆盖率或汽车功能安全认证目标。

iOS 15 真机回归至少覆盖：订阅导入与恢复、搜索、导航进入及返回、状态变化后刷新、视频播放与拖动、旋转及画中画、字幕、HDR 软件转换、下载、音乐队列及歌词跟随、二维码登录、照片/视频反馈附件、系统分享。

完整 App 编译日志补充修复：播放会话保存所选倍速，iOS 15 的各个恢复播放入口使用该值；`AVPlayer.defaultRate` 只在 iOS 16+ 使用。锁屏信息和手机倍速菜单读取会话值。回归需覆盖：暂停后恢复、历史位置恢复、循环播放、下一集及临时加速释放后的倍速；音轨/字幕加载期间切换视频时，应丢弃旧项目的结果。本机没有 Apple SDK，尚未完成这些行为测试或 MC/DC 测量。

[技术债务]
规则/惯例：在 MobilePlayer.swift、PlaybackView.swift 和 PlayerView.swift 局部使用 `@preconcurrency import AVFoundation`，放宽旧 SDK 的 Sendable 静态诊断。
理由：旧 SDK 的媒体选择组和 AVAssetTrack 缺少 Sendable 标注，异步加载涉及这些对象；应用侧由主 actor 管理媒体选择和 PlaybackFormats 的轨道缓存，播放信息刷新保留取消及当前项目身份检查。该导入不能证明底层异步加载无数据竞争。
风险等级：中。
潜在影响：此文件内部分 AVFoundation 跨隔离访问不能完全由编译器检查，需要人工维护其所有权边界。
建议重构时机：更新到提供完整并发标注的 SDK 后移除此兼容导入，并重新执行严格并发检查；这不构成给 AVMediaSelectionGroup 添加 Sendable 承诺。

后续 App 编译摘要另列出 29 条独立诊断，已按对应代码修改：旧版自动更正接口显式传入 `true`；路由注册使用导航回移植；模糊过渡、通用字体加粗、默认焦点、屏幕录制状态和弹层背景增加旧系统路径；文本拼接使用返回 Text 的旧颜色接口；来源分组排序使用旧版 item-provider 拖放保留功能；高斯渐变计算明确 Double 类型；修正 `VideoEnhancementOptions.smooth` 的误替换；后台通知通过主 actor 暂停播放器；视频轨道异步读取采用上述局部 AVFoundation 兼容导入。弹幕、筛选、背景、设置、网页登录和音乐界面拆分为独立视图片段，减小类型推断表达式。

[Pulse] 上述修改后，10 项构建准备检查及全部 79 个 App Swift 文件的 iOS 条件/括号结构检查通过。第三方语法解析器仍有 7 个文件解析崩溃，不能充当 Apple 编译证据。新增回归重点为来源分组拖放、筛选切换/关键字、弹幕开关与导入、订阅添加、网页登录、音乐弹层、等待提示、录屏期间 HDR 处理，以及后台暂停。这些 UI 与异步流程需云编译及 iOS 15.5 真机测试，尚无通过结果或 MC/DC 覆盖率数据。

下一步：提交并推送修改后，手动运行 iOS 15 工作流，核对核心与完整 App 的编译日志；随后完成最终应用链接、签名安装与上述真机回归。

## 2026-11-09 上游适配补充复查

[Raven] 按最新云编译诊断扩大检查本次同步代码的 API 可用性、兼容封装和条件分支。最低部署目标仍为 iOS 15.0，iPhone 生成 spec 仍为 family 1。

[Nova] 修正 iPhone 漫画设置行的 String 局部值及 Binding<String> 作用域，清除前次修改在 tvOS 分支引入的未使用 selected；多行输入在 iOS 16 以下使用 TextEditor，较新系统保留原 TextField；字幕预览使用 coordinateSpace(name:)；订阅导入使用固定 ToolbarItem，条件放在项目的 ViewBuilder 内部。另外补齐 iOS 15 详情页窄屏布局的 continuation 参数，使“继续观看”按钮标签与较新系统一致。此参数仅影响标签，本身不是详情加载故障修复。

[Argus] 对上述四文件和新增菜单、无障碍、触觉反馈封装做只读复核，未发现其他可确证的编译遗漏。命中的原生 Layout、ViewThatFits、字幕翻译等接口逐项查看版本保护；macOS/tvOS 独有调用不算 iPhone 缺陷。源码审查不能替代 Apple 编译器。

[Pulse] 33 项本地 BuildChecks、工作流 YAML 与仅 iPhone spec 约束检查通过，差异空白检查通过。全量条件分支扫描覆盖 348 个 Swift 文件，7 文件导致 tree-sitter 进程异常，不能视为这些文件通过；最新改动四文件单独扫描无发现。可测性：地区码/正则/字幕匹配等纯逻辑可单测，UI 生命周期及 AVFoundation 回调需要 Apple 环境；本次没有 MC/DC 覆盖数据。云编译后回归漫画选项保存、多行输入与清空提示、字幕拖动、导入工具栏状态，以及继续观看标签。点播停在“加载视频详情”仍待故障运行日志定位，尚未确认修复。
