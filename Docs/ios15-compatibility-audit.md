# iPhone / iOS 15 兼容性核对

[Raven] 本次目标为 iPhone arm64、最低 iOS 15.0：检查源码和部署配置，替换旧系统不可用的接口，再通过云端 Apple 编译器检查。当前完成的是源码兼容修改及本地静态验证，尚未确认完整应用可以安装或运行。

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

下一步：提交并推送修改后，手动运行 iOS 15 工作流，核对核心与完整 App 的编译日志；随后完成最终应用链接、签名安装与上述真机回归。
