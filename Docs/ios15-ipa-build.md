# iPhone iOS 15.5 云构建与安装

将本轮所有修改提交并推送到 GitHub，在 Actions 中选择 **iPhone iOS 15 IPA**，点击 **Run workflow**，选择包含这些修改的分支。

工作流先运行已有 Core/App 源码编译检查，成功后执行 **Build iPhone iOS 15 unsigned IPA**。第一次需要构建 JVM、原生绑定和 Python 扩展，可能耗时较长；完整运行时缓存命中后会跳过这些步骤。macOS runner 排队时间取决于 GitHub 容量。

构建提速：Core 检查和 IPA job 共享已编译的 iPhone FFmpeg 缓存，只缓存完整 XCFramework，不缓存源码和中间目录；键包含操作系统、架构、Xcode 版本和 FFmpeg 脚本哈希。FFmpeg 完成后立即保存，即使后续 Swift 编译失败也能在下次复用。脚本仍负责恢复链接和校验，不跳过 iOS 15 编译与 IPA 二进制检查。

完整 Java/Python/Node 缓存仅随其构建脚本、Runtime 和相关 Config 变化失效，单独修改 IPA 打包或二进制检查脚本不会触发运行时重建。三个运行时全部准备完成后立即保存缓存，后续归档失败也不丢失已完成的依赖构建。缓存键本次升级为 v2，首次需要重新生成运行时缓存；后续命中时收益才会体现。缓存可能被 GitHub 驱逐，未命中时仍执行完整构建；没有设置跨版本的模糊恢复键。

[Pulse] 验证提速：在同分支、相同 Xcode 上连续运行两次，第二次应显示 FFmpeg 与运行时缓存命中，FFmpeg 日志含 `FFmpeg is up to date`，Java/Python/Node 构建步骤跳过。比较步骤耗时与排队耗时，不能将 runner 排队减少算成编译加速。首次缓存生成及实际节省时间需云端验证，本地未测得提速比例。

仅构建 iPhone arm64、最低 iOS 15.0 的 App，不构建 iPad、tvOS、模拟器或 Mac App。macOS JDK/jlink 等是构建 iPhone 运行时所需的宿主工具。正式项目由 project.yml 临时裁剪，其他平台配置保持原样。

成功后下载 `Yingxia-iPhone-iOS15-unsigned-运行编号`，解压得到：

- `Yingxia-iPhone-iOS15-unsigned.ipa`
- 同名 `.ipa.sha256` 校验文件

将 IPA 导入支持 iOS 15.5 的侧载签名工具，例如 AltStore 或 SideStore，使用自己的账号/证书签名后安装。IPA 未签名，不能直接点击安装；大体积 App 和嵌套 Python/Node frameworks 需要签名工具完整处理。免费账号的有效期及安装限制由签名服务决定。不要直接下载到旧运行的日志产物中寻找 IPA。

构建会要求 Java、Python、Node 运行时存在，核验所有嵌入 Mach-O 的 arm64 设备架构及最低系统版本，并检查 Java 的 JIMAGE_Open 符号。若某个上游二进制要求高于 iOS 15，任务失败并显示具体文件；不得只降低 plist 来绕过检查。真实兼容仍以安装测试为准，二进制元数据检查不能证明所有动态符号和行为兼容。

失败时下载 `iphone-ipa-logs-运行编号`：`java-device.log`、`python-device.log`、`node-device.log`、`ios15-archive.log` 分别用于定位对应阶段。校验报告为 `ios15-binary-report.json`。只有 **Build iPhone iOS 15 unsigned IPA** 成功且 IPA 上传成功，才表示生成了产物。

云归档使用 `-skipMacroValidation`，跳过 Xcode 对 Perception 宏的交互式信任确认；仍编译并执行宏，Perception 版本继续固定为 1.6.0。该选项不会关闭 Swift 类型检查或并发诊断。

功能边界：保留 Java/DEX、Python、Node 源及播放器现有实现。仓库原有 iOS Python 脚本未包含 cffi/cryptography，这一限制继续存在；依赖这些模块的源未保证可用。官方弹幕 API 需要开发者自有凭据，默认不会包含原作者私密配置；iCloud 权限需要自己的开发者配置。所有源的网络服务、登录和 iOS 15.5 真机行为均需回归，不以打包成功代替测试。

文件安全：构建调用链用到的旧目录保留在 `build/preserved/`，下载临时文件保留；不执行递归删除。GitHub 临时 runner 生命周期结束后，由平台回收工作区。

[Pulse] 真机至少验证冷启动、导航和状态刷新、订阅导入、各类型源搜索/播放、拖动与倍速、横竖屏、画中画、字幕、音乐、下载、照片/分享及网页登录。部署信息解析是纯函数，可自动测试；异步运行时和 UI 需要设备回归，未测量 MC/DC 覆盖率。
