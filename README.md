<p align="center">
  <img src="assets/qianmeng-logo.png" alt="千梦" width="300">
</p>

# 千梦

千梦是基于 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（DSH）定制的智能助手产品。本安装器会完成千梦所需组件的安装与配置，让你可以按习惯使用浏览器 Web 或千梦客户端。

> 千梦是高度定制化产品。需要通用 DSH、安装其他产品，或不了解千梦部署约定时，请使用 [dsh-installer](https://github.com/ningbonb/dsh-installer)。

## 使用方式

### 浏览器 Web

选择「浏览器 Web」后，千梦会在默认浏览器中打开。适合临时使用，以及希望直接在浏览器中工作的场景。

### 千梦客户端

选择「千梦客户端」后，千梦会以独立窗口运行。客户端与 Web 共用同一份会话、插件和设置。

首次启动客户端时，Electron 可能需要下载运行时，请耐心等待；后续启动不会重复下载。

## 安装与启动

| 文件 | 平台 |
| --- | --- |
| `qianmeng.command` | macOS（Linux 下也可通过 `bash` 运行） |
| `qianmeng.bat` | Windows |

### macOS

1. 双击 `qianmeng.command`。
2. 如果系统阻止打开，请右键点击文件并选择「打开」。
3. 首次运行会自动安装所需组件；完成后选择「浏览器 Web」或「千梦客户端」。

### Windows

1. 双击 `qianmeng.bat`。
2. 首次运行会自动安装所需组件；如果系统提示 Node.js 安装完成后需要刷新环境，请关闭窗口再运行一次脚本。
3. 选择「浏览器 Web」或「千梦客户端」。

## 保持最新

安装器会在后台检查自身和 DeepSeek Harness 的更新。发现新版本时，会在下次启动询问是否更新；只有确认后才会开始下载或安装。

## 许可证

MIT
