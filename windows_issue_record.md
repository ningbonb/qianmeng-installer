# qianmeng.bat 闪退问题排查记录

> 记录 `qianmeng.bat`（千梦安装器，DeepSeek Harness / dsh 的封装）从"双击闪退"到"Web 与客户端均可正常启动"的完整排查与修复过程。

---

## 一、问题现象

双击 `qianmeng.bat` 后窗口**一闪而过**，看不到任何错误信息。用命令行运行时能看到形形色色的报错，例如：

```
'5726_logo.png"' 不是内部或外部命令，也不是可运行的程序或批处理文件。
'ersion){' 不是内部或外部命令...
'览器' is not recognized as an internal or external command...
启动失败，日志：C:\Users\renke\.qianmeng-installer\qianmeng.log
```

这些报错来源不同、位置不同，本质上是**多个独立问题叠加**，需要逐个定位。

---

## 二、排查方法论

1. **闪退看不到错误 → 用命令行运行**，让窗口保留：
   ```
   cmd /k "E:\F\popo\qianmeng.bat"
   ```
2. **看日志文件**：`C:\Users\renke\.qianmeng-installer\qianmeng.log`
   - 日志/状态目录是否为空，可判断脚本崩在"启动阶段之前"还是"启动阶段"。
3. **字节层面检查**文件的换行符（LF vs CRLF）、编码（UTF-8 vs GBK）、BOM。
4. **单独复现**某一段逻辑或某条命令，缩小崩溃范围。
5. **读第三方插件源码**，理解它到底怎么调用外部程序。

---

## 三、发现的 4 个问题及修复

### 问题 1：`.bat` 文件是 LF 换行（致命，导致闪退）

**现象**：`BRAND_PLUGIN_NAME`、`-Command`、中文串被切碎当成命令 → 一堆 `不是内部或外部命令`。

**根因**：整个 `.bat` 是 **Unix 换行（LF）**，258 行没有一个 CRLF。Windows 的 `cmd.exe` 批处理解析器**要求 CRLF**，遇到纯 LF 时对多行 `set`、长命令、`set /p < 文件` 的解析会错乱。

> 隐患点：用会保存成 LF 的编辑器（某些配置的 VSCode）改这个文件，就会复现。

**修复**：全文 LF → CRLF（保持 UTF-8 无 BOM，后又改为 GBK，见问题 3）。

---

### 问题 2：`start "" /b powershell -Command "..."` 转义错乱

**现象**：`'5726_logo.png"'`、`'5).tag_name'`、`'ersion){'` 被当成命令。

**根因**：`start` 会把后面的整条命令**二次解析**，导致那段 PowerShell 长字符串的引号配对和 `^|` 转义全部错位，字符串里的 URL 片段、`)`、`{` 脱离引号保护被 cmd 当成独立命令执行。

**涉及行**：第 19、26 行（后台静默检查更新版本号，失败也不影响主流程，只是刷屏）。

**修复**：加一层 `cmd /c` 包裹，让整段 powershell 参数被完整传递而不被 `start` 拆解：
```bat
start "" /b powershell ...          （改前）
start "" /b cmd /c powershell ...   （改后）
```

---

### 问题 3：中文在 UTF-8(65001) 代码页下被拆碎（导致选菜单时闪退）

**现象**：选择使用方式时，`浏览器`、`客户端` 被拆成 `览器`、`c` → 报 `is not recognized`。

**根因**：控制台活动代码页是 65001(UTF-8)，但 `cmd` 在 UTF-8 模式下解析**含中文的批处理**不稳定（尤其中文后跟空格/括号，如 `浏览器 Web`），会把多字节中文拆错。

**系统信息**：控制台代码页 65001；系统 ANSI 代码页 936(GBK)。

**修复**（改用系统原生中文编码，解析百分百稳定）：
- 第 3 行 `chcp 65001 >nul` → `chcp 936 >nul`
- 整个文件从 UTF-8 转存为 **GBK(936)** 编码（保持 CRLF、无 BOM）

**顺手修的脚本 bug**：第 116 行 PowerShell 版本比较 `if(...)` 少一个右括号，导致后台更新检查报 `意外的标记"{"`。已补上括号。

---

### 问题 4：千梦客户端 `spawn dsh ENOENT`（选客户端模式时启动失败）

**现象**：选 `[2] 千梦客户端` 时日志报：
```
dsh-web-desktop: could not start dsh: spawn dsh ENOENT
dsh: pnpm failed in profile directory C:\Users\renke\.dsh\profiles\web
```

**根因**：客户端插件 `dsh-web-desktop` 的 `cli.js` 用 Node 的 `spawn` 启动 `dsh`，**没有加 `shell: true`**：
```js
spawn(DSH_BIN || "dsh", args, { stdio: "inherit" });
```
在 Windows + 现代 Node 上这是死结：
- `spawn("dsh")` → **ENOENT**：Node 的 spawn 不走 Windows 的 PATHEXT，找不到无后缀的 `dsh`，也无法执行 `#!/bin/sh` 脚本。
- `spawn("dsh.cmd")`（通过 `DSH_BIN` 指定）→ **EINVAL**：Node 因安全修复 **CVE-2024-27980** 禁止不带 `shell:true` 直接执行 `.cmd`/`.bat`。

> **关于"升级 Node 能否解决"：不能。** EINVAL 是 Node 的**安全特性**，所有更高版本都保留且更严格，升级只会让问题依旧。这是插件自身的 Windows 兼容 bug，不是 Node 的问题。

**修复思路**：给 `DSH_BIN` 指向一个**原生 `.exe`**（Node 任何版本都能直接 spawn，无 ENOENT/EINVAL）。

**具体方案**：脚本新增 `:ensure_dsh_shim` 子程序，客户端启动前自动：
1. 用 **Windows 自带的 C# 编译器 `csc.exe`**（`C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe`）编译一个 ~4.6KB 的原生 `dsh-shim.exe`。
2. 该 exe 被 spawn 调用时，把所有参数转发给 `node bin.js`（`bin.js` = dsh 的真实 JS 入口）。
3. 通过 `DSH_BIN` 环境变量让插件使用这个 shim。

**关键设计**：
- shim 存放在 `%USERPROFILE%\.qianmeng-installer\`（**node_modules 之外**），脚本每次重装插件都不会覆盖它。
- 只在首次编译一次，之后直接复用。

**shim 的 C# 逻辑要点**（避坑）：
- 判断参数是否需要加引号时，用 `IndexOfAny(...) == -1` 代替 `< 0`，**避开 `<` 字符**——因为在 `> file echo ...` 重定向里 `<` 需要转义，转义符 `^` 容易残留进 `.cs` 文件导致编译失败。
- 查找 csc.exe 时用**直接路径判断** `if exist`，不要用 `dir /b /s "...\v4*\csc.exe"`（`/s` 递归 + 中间目录通配 `v4*` 不展开，会找不到）。

---

## 四、最终文件状态（务必保持）

| 项目 | 值 |
|------|-----|
| 文件 | `E:\F\popo\qianmeng.bat` |
| 编码 | **GBK (936)** |
| 换行 | **CRLF** |
| BOM | 无 |
| shim | `%USERPROFILE%\.qianmeng-installer\dsh-shim.exe`（自动生成） |

---

## 五、验证结果

- **Web 模式**：菜单中文正常 → `dsh web` 启动成功（http://127.0.0.1:3080）→ 自动打开浏览器。
- **客户端模式**：脚本自动编译 shim → `dsh web` 启动成功 → **Electron 客户端真实拉起**，`spawn dsh ENOENT` 彻底消失。（首次进客户端会下载一次 Electron，属正常。）

---

## 六、给未来的提醒

1. ⚠️ **不要用会保存成 LF 或 UTF-8 的编辑器改这个 `.bat`**，否则会重新触发问题 1 / 问题 3 的闪退。改完请确认编码=GBK、换行=CRLF。
2. `.cmd`/`.bat` 在批处理里传给外部程序做参数时，注意 `start`、`for /f`、`echo >file` 各自的转义规则不同，长命令建议单独复现验证。
3. 现代 Node 在 Windows 上 `spawn` 一个程序名（无 `shell:true`）时，**只能可靠地执行 `.exe`**；`.cmd`/`.bat`/无后缀脚本都会失败。第三方工具若有此问题，用"原生 exe 转发器 + 环境变量指定路径"是通用解法。
