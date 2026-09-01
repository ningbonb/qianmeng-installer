<p align="center">
  <img src="assets/qianmeng-logo.png" alt="千梦" width="260">
</p>
<h1 align="center">千梦</h1>


千梦安装器基于 DeepSeek Harness，本安装器会自动完成所需组件的安装与配置。启动后，选择你习惯的使用方式即可。

> 该仓库是高度定制化产品。若不了解千梦时，请使用 [dsh-installer 安装官方版本](https://github.com/ningbonb/dsh-installer)。

## 开始使用

| 文件 | 平台 |
| --- | --- |
| `qianmeng.command` | macOS（Linux 下也可通过 `bash` 运行） |
| `qianmeng.bat` | Windows |

1. 双击 `qianmeng.command`，macOS 若系统阻止打开，请右键选择「打开」。Windows 双击 `qianmeng.bat`。
2. 首次运行会自动安装所需组件。Windows 安装 Node.js 后如提示刷新环境，请关闭窗口再运行一次。
3. 在菜单中选择使用方式。

| 选择 | 适合场景 |
| --- | --- |
| 浏览器 Web | 希望直接在默认浏览器中使用 |
| 千梦客户端 | 希望使用独立桌面窗口 |

客户端与 Web 共用会话、插件和设置。首次启动客户端可能需要下载 Electron，请耐心等待；后续不会重复下载。

## 更新

安装器会在后台检查自身和 DeepSeek Harness 的更新；发现新版本后，会在下一次启动询问是否更新。

## 开发者

安装器维护、测试和发布说明见 [DEVELOPMENT.md](DEVELOPMENT.md)。

## 许可证

MIT
