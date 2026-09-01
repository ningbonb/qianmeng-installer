# 千梦安装器

面向千梦用户的一键安装与启动脚本。千梦是基于 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`）高度定制的产品：安装器复用 DSH 的 Web profile，并自动配置千梦所需的品牌和客户端组件。

> 本安装器和千梦产品均为高度定制化版本。不了解千梦部署约定、需要通用 DSH，或要安装其他产品时，请使用 [dsh-installer](https://github.com/ningbonb/dsh-installer)。

## 文件

| 文件 | 平台 | 用途 |
| --- | --- | --- |
| `qianmeng.command` | macOS（Linux 下也可通过 `bash` 运行） | 一键安装并选择浏览器或千梦客户端启动 |
| `qianmeng.bat` | Windows | 一键安装并选择浏览器或千梦客户端启动 |

脚本使用英文文件名，避免中文路径和编码在跨平台终端中的兼容性问题；产品显示名称为「千梦」。

## 使用方法

### macOS

1. 双击 `qianmeng.command`。
   - 首次运行若被 Gatekeeper 拦截，请右键选择「打开」，或先执行 `chmod +x qianmeng.command`。
2. 缺少或损坏 `dsh` 时，脚本会引导安装 Node.js、pnpm 和 `@deepseek-ai/dsh`。
3. 安装完成或之后的每次启动，选择「浏览器 Web」或「千梦客户端」。

### Windows

1. 双击 `qianmeng.bat`。
2. 缺少 `dsh` 时，脚本会使用 winget 安装 Node.js，并继续安装 pnpm 和 `@deepseek-ai/dsh`；新安装的 Node.js 未进入 PATH 时，请关闭窗口后重新运行脚本。
3. 安装完成或之后的每次启动，选择「浏览器 Web」或「千梦客户端」。

## 千梦预置内容

脚本会在 DSH 的 `web` profile 中自动安装下列插件，并可重复运行而不重复添加已存在的依赖：

1. [dsh-client-ui-brand](https://github.com/ningbonb/dsh-client-ui-brand)
   - 将产品名称设为「千梦」。
   - 将产品图标设为 `https://sales.ws.126.net/minisite/2026/0901/1788255726_logo.png`。
   - 配置写入 `$DSH_HOME/profiles/web/cordis.patch.yml`；未设置 `DSH_HOME` 时，默认目录为 `~/.dsh`（Windows 为 `%USERPROFILE%\.dsh`）。
2. [dsh-web-desktop](https://github.com/ningbonb/dsh-web-desktop)
   - 浏览器和客户端共用同一份 Web profile、插件、会话和模型设置。
   - 选择「千梦客户端」时会通过该插件启动 Electron 窗口；客户端使用随机端口，不会占用已运行的浏览器 Web 服务。

首次选择「千梦客户端」时，Electron 可能需要下载运行时，因此请耐心等待。这个提示只会显示一次；后续启动不会重复下载该运行时。

## 更新与发布

两个脚本均会在后台检查本仓库的最新 GitHub Release，不会阻塞当前启动。发现较新的版本后，会在下一次启动时询问是否下载；下载内容在下一次启动时校验并替换当前脚本。

脚本也会在 `dsh` 已安装时异步查询 npm 中 `@deepseek-ai/dsh` 的最新版本。发现 DeepSeek Harness 有新版本后，会在下一次启动时询问是否更新；确认后才执行全局 npm 更新，并继续使用同一份千梦 Web profile。

发布前更新两个脚本顶部的 `QIANMENG_INSTALLER_VERSION`，并创建同版本 GitHub Release，例如 `v0.1.2`。安装器仓库必须保持为 `ningbonb/qianmeng-installer`，以便后续产品版本依赖可追溯。

## 许可证

MIT
