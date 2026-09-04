# 千梦安装器开发说明

本文面向维护 `qianmeng-installer` 的开发者。面向最终用户的说明只保留在 [README.md](README.md)。

## 目标与边界

千梦安装器是 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（DSH）的定制入口，不修改 DSH 核心。它在既有的 `web` profile 上完成以下工作：

- 安装 `@deepseek-ai/dsh`、`dsh-client-ui-brand` 与 `dsh-web-desktop`；
- 写入千梦品牌名称和 logo 配置；
- 让用户选择浏览器 Web 或 Electron 客户端；
- 分别检测安装器 Release 和 npm 上的 DSH 版本更新。

通用 DSH 用户不应使用本安装器，应转至 [dsh-installer](https://github.com/ningbonb/dsh-installer)。

## 仓库结构

| 路径 | 说明 |
| --- | --- |
| `qianmeng.command` | macOS/Linux Bash 安装与启动脚本 |
| `qianmeng.bat` | Windows 安装与启动脚本 |
| `assets/qianmeng-logo.png` | README 展示用千梦 logo |
| `README.md` | 最终用户指南 |

## Profile 配置

脚本使用 `$DSH_HOME/profiles/web`；未设置 `DSH_HOME` 时使用 `~/.dsh/profiles/web`，Windows 使用 `%USERPROFILE%\.dsh\profiles\web`。

品牌配置写入 `cordis.patch.yml`：

```yaml
- id: dsh-client-ui-brand
  config:
    productName: 千梦
    logoUrl: https://sales.ws.126.net/minisite/2026/0901/1788255726_logo.png
    logoAlt: 千梦 logo
```

`cordis.patch.yml` 必须是 YAML 顶层数组。文件内容为 `[]` 时，写入品牌条目前必须移除这个空数组；不能将新的 `- id` 条目追加在 `[]` 后面。

## 组件版本清单

安装器顶部声明当前 Release 验证过的插件版本：

| 组件 | 当前声明 |
| --- | --- |
| 品牌插件 | `dsh-client-ui-brand@0.1.10` |
| 客户端插件 | `dsh-web-desktop@0.1.0` |

首次安装会以完整 spec 安装这两个版本。安装器 Release 更新后，脚本会检测 `components_version` 与当前 `QIANMENG_INSTALLER_VERSION` 不同，并再次以完整 spec 执行 `dsh plugin --profile web add`。这会把 profile 对齐到新 Release 的组件清单；平时启动不会重复更新插件。

## 启动行为

- Web：运行 `dsh web`，默认使用端口 `3080`；端口已占用时提示用户处理。
- 客户端：运行 `dsh plugin --profile web exec dsh-web-desktop -- --port 0`，使用随机端口以避免与已打开的 Web 服务冲突。
- 客户端首次启动提示 Electron 可能需要下载运行时。该提示由 `~/.qianmeng-installer/desktop_first_use`（Windows 对应用户目录）记录。

## 更新机制

安装器状态目录为 `~/.qianmeng-installer`，Windows 对应 `%USERPROFILE%\.qianmeng-installer`。

| 检测对象 | 后台来源 | 状态文件 | 更新方式 |
| --- | --- | --- | --- |
| 安装器脚本 | GitHub `releases/latest` | `latest_tag`、`seen_tag` | 下载同一 tag 下的新脚本，并在下次启动替换 |
| DeepSeek Harness | npm `@deepseek-ai/dsh` | `dsh_latest_version`、`dsh_seen_version` | 用户确认后执行全局 `npm install -g @deepseek-ai/dsh@latest` |

插件不单独检查 npm 最新版。每个安装器 Release 都固定一组经过验证的插件规格；安装器更新并在下一次启动完成组件校准后，会新增缺失插件或将已有插件调整到脚本中指定的版本。

检测不应阻塞当前启动。只要本机仍落后于已检测到的版本，更新入口就持续显示在启动菜单中；不再记录“已忽略”的版本。

## 本地验证

macOS/Linux 至少运行：

```sh
bash -n qianmeng.command
```

不要在日常验证中直接修改真实 profile。使用临时 `HOME`、`DSH_HOME` 和假的 `dsh` 可执行文件，覆盖以下行为：

1. 已安装插件时生成品牌 patch。
2. patch 为 `[]` 或曾被错误写成 `[]` 加条目时，脚本会修复为合法数组。
3. 选择 Web 和客户端时调用的命令正确。
4. 检测到安装器或 DSH 新版本时，版本号会正确解析 `-rc.1` 等预发布版本，并在菜单中持续显示更新入口。

Windows 改动至少审查批处理控制流、GBK 编码与 CRLF 换行，以及 `cmd.exe` 的变量展开；在 Windows 主机上手工验证安装、Web 和客户端两种入口。

## 发布

1. 选定经过验证的品牌与客户端插件版本，并同时更新两个脚本和本文档的组件清单。
2. 同时更新 `qianmeng.command` 和 `qianmeng.bat` 顶部的 `QIANMENG_INSTALLER_VERSION`。
3. 运行对应的静态检查和隔离启动验证。
4. 提交并推送 `main`。
5. 创建相同版本号的 GitHub Release，例如 `v0.1.3`。
6. 上传 `qianmeng.command` 与 `qianmeng.bat` 作为 Release 附件。
7. 确认 GitHub `releases/latest` 返回新 tag；这是安装器异步更新检测的唯一 Release 来源。
