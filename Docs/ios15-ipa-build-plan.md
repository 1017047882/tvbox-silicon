# iPhone iOS 15 IPA 云构建方案

目标：仅生成 iPhone arm64、最低 iOS 15.0 的未签名 IPA，供 iOS 15.5 侧载签名安装。

1. 保留已通过的 Core/App 源码检查，后续独立任务使用 arm64 macOS runner。
   验证：任务依赖源码检查成功；不启动 tvOS、模拟器、Mac App 构建。
2. 调用现有 FFmpeg、Java/JVM、Python、Node 构建脚本，完整运行时必须存在。
   验证：缺失任一运行时即失败；使用与工具链和源码绑定的完整产物缓存。
3. 从 project.yml 生成仅包含 TVBox-iOS 的临时工程，限制设备族为 iPhone。
   验证：Xcode Release archive，关闭代码签名，不使用发布账户。
4. 检查 App 和嵌入 Mach-O 的设备平台、arm64 架构、最低系统要求及 Java 导出符号，再以 Payload 结构打包。
   验证：使用合成二进制单元测试覆盖架构、平台、版本和格式拒绝路径；云端验证真实产物。
5. 上传 IPA、校验和与日志，失败仍保留日志。
   验证：YAML 解析、Bash 语法和本地构建准备检查；最终 IPA 成功以云构建和 iOS 15.5 真机为准。

文件安全：本次调用链中的递归删除改为移动旧目录到 build/preserved；不删除旧输出。
功能边界：沿用仓库原有 Python 依赖范围；缺少开发者私有弹幕凭据时，官方 API 功能不可用，不能宣称所有源均能运行。侧载签名不包含原作者 iCloud 权限。
