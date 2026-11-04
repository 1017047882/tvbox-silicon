# iOS 15 实际编译前置操作计划

目标：将部署参数统一为 iOS 15，并在 GitHub Actions 上实际编译 TVCore，获得编译诊断。此阶段不包含完整应用移植或 IPA 打包。

架构：复用现有 FFmpeg 配方，使用全新构建目录，禁止递归清理；通过 SwiftPM 交叉编译 iOS 真机核心模块。保留原有预检查，并增加独立的实际编译任务。

技术栈：Swift 6、SwiftPM、FFmpeg/dav1d、GitHub Actions、Python unittest。

约束：最低 iOS 15.0；tvOS 17.0 不变；不执行递归删除；不关闭 API 可用性检查；不将核心编译成功表述为应用或 IPA 构建成功。

## 步骤与验收

- [x] 在 `Tests/BuildChecks/test_ios15_build_preparation.py` 增加部署参数和 FFmpeg 文件保留测试，运行并确认在修改前失败。
- [x] 修改 `project.yml`、`Package.swift` 和相关原生构建脚本：仅降低 iOS 版本，按目标区分共享的 CMake/Python 最低版本。
- [x] 将 `Scripts/build-apple-ffmpeg.sh` 中的递归清理改为全新工作目录；仅在原链接确为符号链接时替换它，遇到普通文件或目录停止，保留原内容。
- [x] 为 `.github/workflows/build-ios15.yml` 增加实际编译任务：准备 FFmpeg、执行 `swift build --target TVCore --triple arm64-apple-ios15.0`、无论成功失败均上传日志。编译失败保留任务失败状态。
- [x] 运行 Python 回归测试、Shell 语法检查、工作流内嵌脚本检查和差异检查。
- [x] 生成仅包含所需改动的上传包和中文操作说明，明确尚需迁移观察、导航、其他 API，并完成真机验证。

云端验收：依赖准备完成后，日志实际出现 Swift 编译命令；不兼容代码必须产生真实诊断，而非文本扫描结果。若依赖下载失败，先根据对应日志处理，再继续编译。此工作区没有 Xcode，不能在本地验证 Apple 编译结果。
