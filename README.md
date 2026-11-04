# 《极限竞速：地平线 5》CrossOver Preview 补丁

为 Steam 版《地平线 5》提供 D3D12 兼容补丁。补丁在 D3DMetal 前接管时间戳查询，解决本机测试中游戏卡在标题菜单和点击 Continue 后持续加载的问题。

## 适用环境

- Apple 芯片 Mac，macOS 27 或更新版本。
- 已注册的 CrossOver Preview **27.0.0.41073**，使用该构建附带且与安装器校验值匹配的 **D3DMetal 4.0b3**。
- Steam 版《地平线 5》**688.109**（AppID `1551360`）。请先在 Preview 中启用装有 Windows 版 Steam 和游戏的容器。

安装器核对 Preview 构建号和 D3DMetal 文件。升级 Preview 或更换为正式版后需要重新验证。此项目是社区兼容补丁。

## 下载与使用

在 [Releases](https://github.com/aiwentongxue/fh5-crossover-preview-patch/releases) 下载合并版 ZIP，解压完整目录。安装前退出 Windows 版 Steam 和游戏。

- **[v1.2.0](https://github.com/aiwentongxue/fh5-crossover-preview-patch/releases/tag/v1.2.0)**。在 Preview 中把目标容器的图形后端设为 D3DMetal。打开 `地平线5补丁.app`，选择该容器并点击「安装补丁」。稍后从 CrossOver Preview 打开 Steam，在游戏库里启动游戏。
- **[v1.1.2](https://github.com/aiwentongxue/fh5-crossover-preview-patch/releases/tag/v1.1.2)**。打开 `地平线5补丁.app`，选择容器，点击「打补丁并启动」。
- 两个版本均可从 `终端版/启动地平线5.command` 打补丁并直接启动游戏。需要手动指定 Steam 时，请选择该容器使用的 Windows 版 `steam.exe` 实际文件。App 使用临时签名，尚未经 Apple 公证。

恢复时先退出游戏和 Windows 版 Steam。用 App 选择同一容器并点击「恢复原始 DLL」，或执行 `终端版/恢复原始DLL.command`。v1.2.0 的恢复也会撤销它添加的启动设置。工具将原始 DLL 备份保存在 `~/Library/Application Support/FH5 Preview Patch/`。

## 验证范围

本机曾用此 D3D12 补丁方案进入游戏并正常驾驶。已验证 v1.1.2 能识别并恢复早期包安装的补丁 DLL，也在隔离容器中验证了 v1.2.0 安装、普通启动的 Windows 子进程加载补丁以及恢复。v1.2.0 从 Steam 游戏库完整试玩和联机尚待验证。

## 源码、构建与许可证

D3D12 shim 源自 [Highball 提交 5ce643e](https://github.com/gauthierpiarrette/highball/tree/5ce643ef6545126c8c5dac6fd8a17f6ca21c65a1/spike/tsshim)，保留其署名与许可。此项目增加了面向 CrossOver Preview 的安装和恢复脚本、Steam 路径检测、macOS App 和终端入口。v1.2.0 增加了 App 仅安装补丁、稍后从 Steam 启动的流程。

项目以 [GPL-3.0](LICENSE) 分发。每个 Release 的标签包含对应源码和构建脚本。发行包中的 D3D12 shim 是开源组件。工具在本机读取用户已安装的 D3DMetal。

在 Apple 芯片 Mac 上安装 Xcode Command Line Tools 和 MinGW-w64 后，从相应标签运行 `bash build.sh`。生成的 ZIP 位于 `dist/`。重新构建的文件校验值可能随编译环境变化。
