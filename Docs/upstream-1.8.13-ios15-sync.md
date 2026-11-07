# 上游 1.8.13 快照适配计划与记录

[Raven] 目标：以当前 iOS 15.5 工程为基础合入用户提供的 `../tvbox-silicon-main` 快照。快照没有 Git 历史，版本标记为 1.8.13（51），不能声称核实了上游最新提交。当前基线为 `8617d54`，共同内容基线选用本地保留的 `2ffb56e`。不覆盖整个工程，不提交或推送。

1. 三方比较共同基线、当前工程和快照；先在 build/upstream-sync 生成候选，再审查冲突。验证：逐文件清单、保存原文件备份、无未解决标记。
2. 合入功能与修复并延续 iOS 15 适配。验证：新旧 Swift 条件分支解析、新 API 和状态跟踪检查、运行时/链接依赖检查。
3. 保留 iPhone 工作流、最低系统要求、Perception/NavigationBackport、发现页任务组、旋转/AirPlay、日志分享和来源页诊断。验证：针对这些位置审查最终差异。
4. 运行适用的本地检查并提供云端与设备回归清单。验证：BuildChecks、可运行的 JavaScript/Python 测试、YAML/Shell 语法及差异检查。Windows 无 Xcode，不能在本机证明 IPA 或 iOS 真机通过。

[Argus] 已知取舍：上游要求 iOS 17，不能恢复其部署设置。上游新增 Node 26 预编译包，尚无最低版本证据，当前 iOS15 构建继续使用已固定的 Node 18。上游构建脚本中的递归删除不得引入当前构建链路。快照解压的符号链接可能为文本文件，保留当前仓库链接记录。

[Pulse] 合入前 BuildChecks：24 项通过。运行时和 UI 含异步、有状态逻辑，纯源码检查不能证明功能正确或 MC/DC 覆盖率；最终设备回归至少覆盖发现、来源页、旋转、AirPlay、日志分享、新字幕来源、漫画入口与各类型插件。

## 本次落地记录

[Nova] 已审查三方清单中的 348 项上游变化，并将候选合入工作区。上游功能包括漫画订阅/阅读、外部字幕文件/在线字幕来源/样式和延迟、播放器剧集选择、直播弹幕与断流重开、来源页加载更多、推荐栏目、插件 Android 兼容类和原生运行时内存限制。版本标记跟随快照为 1.8.13（51）。这是本地快照的内容适配，不是具有上游父提交的 Git merge；仍需用户提交并推送。

保留及适配：

- iPhone Actions、Perception/NavigationBackport、最低 iOS 15.0（覆盖 15.5）、侧载 iCloud 权限保护、发现页任务组和旧系统轮播继续使用本地方案。
- 用户已确认页面跳动修复有效；保留无重复动画事务的 TimelineView 和 30 fps 上限，融合上游显式渐变高度修复。来源页独立搜索栏、父布局约束和只读探针保留，分页融合为上游加载更多。
- 投屏的主 actor 桥接与旧系统手势处理、旋转控制器、横屏铺满条件、日志自动分享保留；新字幕覆盖层使用相同的实际铺满条件。
- 新字幕/漫画表单改用 TVLabeledContent；下载网格和自适应标签保留 iOS 15 回退。字幕地址输入在 iOS 15 使用可输入的表单 sheet，较新系统沿用上游 alert。时钟差值与日志改用 TVInstant/TVDelay；直播重试测试的参数类型一并适配。
- 漫画分类/详情的 Layout 协议仅在 iOS 16+ 使用，iOS 15 回退为自适应网格；竖向双击缩放、单击控制栏和横向点击翻页通过 UIKit 保留。safeAreaRegions 增加 iOS 16.4 保护，播放器/漫画的系统覆盖层修饰增加 iOS 16 保护，iOS 15 沿用系统策略。
- HDR 像素传输与工作线程调用增加 iOS 16 可用性保护；iOS 15 返回 ENOSYS，沿用调用方已有软件色调映射回退。新版硬件管线保留，未实测其速度。
- Node mobile 下载仍固定 18.20.4 及原校验值。新版 Node host 明确保留 Node 18 兼容路径；本地协议测试使用桌面 Node 24，并模拟 Node 18 默认关闭 keep-alive 的情形，不代表实际嵌入 Node 18 验证。
- 保留本地 fetch-node-mobile.sh、build-script-host.sh、build-universal-hosts.sh、package-mac-release.sh、testflight-upload.sh；本次不更新桌面发行工具及其新运行时下载行为。其余运行时版本检查、打包标记及 Unicorn 32 MB 翻译缓冲补丁合入；缓存键包含 Runtime/**，本轮将重建受影响的原生运行时。
- 新 runtime 检查脚本在 XcodeGen spec 中显式用 bash 调用，避免 Windows 新文件没有执行位影响云构建。未覆盖解压快照中的符号链接文本。

[Argus] 合并前文件保存在 build/upstream-sync/backup，候选及比较清单在 build/upstream-sync；这些目录被 Git 忽略。原始 tvbox-silicon-main 目录未修改。没有提交、推送或启动云构建。

## 验证与设备验收

[Pulse] 可测性：字幕匹配/时序、重试决策、来源分页已有上游纯逻辑测试随快照合入；UI、AVFoundation 回调和原生媒体管线必须由 Apple 工具链及设备验证。Windows 没有 Swift/Xcode/Java 工具链，未运行 Swift 单元测试或编译 C/Java，未取得 MC/DC 覆盖数据。

本地检查记录：

- 合入前和合入后 BuildChecks 各 24 项通过。
- Node host 本地 HTTP/HTTPS 复用协议测试通过；脚本宿主模块、HTML 解析、持久化、来源初始化/搜索和弹幕协议测试通过。临时输出保留在 build/upstream-sync/test-output。Node 测试启动器使用 pathToFileURL，兼容 Windows 路径。
- 首轮 11 个涉及上游变化的 Shell 文件 bash -n 通过；最终复查实际变更的 6 个 Shell 和 2 个 Node 模块语法通过，工作流 YAML 解析及 iPhone spec 生成约束检查通过。最终 BuildChecks 再跑 24 项通过；git diff --check 通过，未发现未解决的合并标记。
- Swift 条件分支扫描覆盖 348 个文件。tree-sitter 的少数报错/异常在上游也可见；它不能替代类型、可用性、并发检查。新增 ExternalSubtitles/SubtitleSearch 的泛型任务组为解析器不完整支持的位置，仍需 Actions 编译。
- 只读复核指出的两组 iOS 16 API 编译阻断已修改并复核；最后修改的漫画阅读/分类/详情、兼容修饰和播放器共 5 文件，debug/release 条件分支 tree-sitter 扫描无语法发现。仍不能据此替代 Swift 编译。
- 原始翻译检查停在 Filter Type 对应英文 Type 的已有不一致；HEAD 和上游快照相同，本次不改变词条或放宽检查。

Actions 后的验收顺序：确认源码检查与 iPhone IPA 均成功；安装签名后的新 IPA，在 iOS 15.5 上检查发现、来源页空闲 10 秒稳定、搜索与加载更多、投屏设备列表、竖横屏切换/铺满、日志分享；再覆盖内外字幕选择/文件和地址导入/样式延迟/画中画、漫画订阅/阅读、直播弹幕/断流重试和 Java/Python/Node 各类来源。新增大功能尚未取得真机通过结果。

构建入口说明：沿用 `.github/workflows/build-ios15.yml`，由 `make-iphone-project.py` 生成仅 iPhone 的 spec，再运行 XcodeGen。仓库内现成的多平台 `.xcodeproj` 不是本次 iPhone CI 的权威输入，未验证直接打开它能编译。待 Actions 成功后仍须签名安装；漫画双击不连带切换控制栏、缩放后平移/滚动、分页末页点击应列为新增设备回归重点。
