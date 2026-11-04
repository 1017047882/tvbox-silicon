# iOS 15 构建前置操作：上传与运行

## 最新目标范围

用户已限定只需要 iPhone 真机 iOS 15，不构建 Mac、Apple TV 或模拟器产物。Actions 调用 `bash Scripts/build-apple-ffmpeg.sh ios`，只编译 arm64 iPhone 切片；缓存按构建范围隔离。macOS 运行器用于执行 Apple 编译工具，不表示生成 Mac 应用。直接通过 Git 提交和推送本地修改即可，无需使用上传包。

最新日志已确认进入 Swift 源码编译。已将 Downloads 的 URL 路径和默认目录接口、Downloads 与 EmbeddedJarHost 的定时休眠改为 iOS 15 可用接口。`@Observable` 及其他核心和界面 API 兼容问题仍待迁移，VideoToolbox 的 iOS 16 可用性警告也尚未处理。此时重跑仍可能失败，不能视为 IPA 构建完成。

## 已完成的本地准备

- 应用生成配置和 Swift 包的 iOS 最低版本已设为 15.0。
- JVM、libffi、Unicorn、原生绑定、FFmpeg、Python wheel 的相关 iOS 构建参数已调整为 15.0；tvOS 仍为 17.0。
- FFmpeg 使用全新工作目录，保留失败日志，不再递归删除目录，也不会覆盖已有普通文件或目录。
- 工作流增加 `compile-core` 任务：真正构建 libffi、FFmpeg，并调用 Swift 编译器交叉编译面向 iOS 15 真机的 TVCore。
- 本地完成了 5 项回归测试、7 个原生脚本的 Bash 语法检查，以及 YAML、9 个工作流命令块和内嵌 Python 的语法检查。

这些是构建准备，不代表状态观察、导航或全部原生依赖已经兼容。JVM 和 Python 的完整构建本轮未执行，预编译框架兼容性仍需验证。生成的 Xcode 项目也尚未重新生成；后续应用编译前必须运行 XcodeGen，以 `project.yml` 为准。

## 更新 GitHub 仓库

1. 解压 `ios15-build-preparation.zip`。保留里面的目录结构。
2. 打开 GitHub 仓库的代码首页，选择 **Add file → Upload files**。
3. 上传解压后的文件和目录到仓库根目录，覆盖同名文件并提交。不要只上传 ZIP，Actions 不会自动解压它；也不要仅替换工作流，新的任务依赖配套脚本和测试文件。上传后核对 `.github/workflows/build-ios15.yml`、`Tests/BuildChecks/test_ios15_build_preparation.py` 和 `Scripts/build-apple-ffmpeg.sh` 均已更新。
4. 进入 **Actions → iOS 15 build preparation → Run workflow**，选择包含这些改动的分支，启动运行。

当前本地无法连接 GitHub，未能同步或推送最新提交。上传前查看提交差异，确认同名文件没有其他需要保留的远端改动。本包针对本地 `2ffb56e` 源码制作；已知远端预检查运行提交为 `1aa562d`，未核实两者完整差异。

## 查看实际编译结果

- `preflight`：原有源码清单检查，成功不表示编译成功。
- `compile-core`：实际依赖构建和 TVCore 编译。若代码尚不兼容 iOS 15，任务应该失败，并保留真实错误；没有使用 `continue-on-error` 将失败伪装成成功。
- 下载 `ios15-build-preparation-<运行编号>` 产物，先查看 `build-summary.md`。
- `libffi-build.log`：libffi 构建日志。
- `ffmpeg-build.log`：FFmpeg 构建日志；同时保留内部配置和编译日志。
- `ios15-core-build.log`：Swift 编译诊断。只有前面的依赖步骤成功后才会出现；若没有该文件，先处理前序失败。
- `compiler-toolchain.txt`：提交号、处理器架构、Xcode、Swift 和 iOS SDK 版本。

工作流未开启源码或大型二进制缓存，避免恢复不匹配的旧部署版本。原生依赖首次构建可能明显慢于此前 26 秒的预检查。

## 后续达到 IPA 的条件

1. 根据 TVCore 编译错误移植状态观察与较新的核心 API。
2. 移植应用导航与界面 API，并处理选用 SDK 不认识的新符号。
3. 完成 JVM、Python、Node 等运行时的 iOS 15 构建或兼容性验证；执行前处理尚存的递归清理命令。
4. 使用 XcodeGen 重新生成工程，实际编译完整应用；检查所有嵌入框架的最低系统版本。
5. 增加未签名 IPA 打包、签名侧载和 iOS 15 真机验收。

本轮工作流不生成 IPA；其交付目标是从文本检查推进到真实的原生依赖构建和 Swift 编译诊断。
