# Trae Auto Checkin

打开 Trae CN IDE 时**自动签到**，再也不用担心忘记。

## 功能

- **启动自动签到**：打开 Trae CN IDE 后自动执行签到（延迟 5 秒，避免影响启动速度）
- **手动签到**：命令面板搜索 `Trae Checkin: 立即签到`
- **查看状态**：命令面板搜索 `Trae Checkin: 查看签到状态与积分`
- **输出日志**：`Trae Auto Checkin` 输出频道查看 device_id、积分、签到状态等详细信息

## 配置项

| 设置 | 默认值 | 说明 |
|------|--------|------|
| `traeAutoCheckin.autoCheckinOnStartup` | `true` | 启动 IDE 时自动签到 |
| `traeAutoCheckin.startupDelay` | `5` | 启动后延迟秒数再执行签到 |
| `traeAutoCheckin.showOutputOnSuccess` | `false` | 签到成功时也弹出输出面板 |

## 工作原理

1. 从 `%APPDATA%\Trae CN\ahanet\tt_net_config.config` 读取 device_id
2. 从 `%APPDATA%\Trae CN\User\globalStorage\storage.json` 读取加密凭证
3. 解密凭证：Base64 → 提取密钥种子 → 双重 SHA512 派生 → AES-128-CBC 解密 → 提取 JWT token
4. 调用 Trae API 完成签到、查询状态和积分

## 安装

### 从 Open VSX Registry 安装

- 插件主页：https://open-vsx.org/extension/LiHui/trae-auto-checkin
- 在基于 Open VSX 的 IDE（Cursor、VSCodium、Windsurf 等）扩展面板搜索 `Trae Auto Checkin` 即可安装
- Trae CN IDE 使用自有市场，请在扩展面板搜索；搜不到时用下面的方式安装

### 手动安装

将 `.vsix` 文件下载后，在 Trae CN IDE 命令面板中执行 `Extensions: Install from VSIX...`。

### 在其他机器上安装（推荐）

把 `lihui.trae-auto-checkin-<version>.vsix` 和 `install/` 目录一起拷贝，然后：

- Windows：双击 `install\install.bat`（或在 PowerShell 中执行 `.\install\install.ps1`）
- macOS / Linux：`chmod +x install/install.sh && ./install/install.sh`

脚本会优先调用 Trae CN 自带的命令行完成安装，找不到命令行时自动退化为解压到
`~/.trae-cn/extensions/lihui.trae-auto-checkin-<version>`，并清理同名插件的历史版本。

> 插件 ID 为 `lihui.trae-auto-checkin`，扩展目录名必须与 `package.json` 的
> `publisher` + `name` 完全一致（小写），否则 IDE 无法识别。

## 发布到 Open VSX Registry

1. 在 https://open-vsx.org 创建个人访问令牌（PAT），并创建命名空间（只需一次）：
   ```
   npx ovsx create-namespace LiHui -p <你的 PAT>
   ```
   `package.json` 的 `publisher` 必须与命名空间**大小写完全一致**（本项目为 `LiHui`）。
2. 提升 `package.json` 中的 `version`（同一版本号不能重复发布）。
3. 发布：
   ```powershell
   # Windows PowerShell
   $env:OVSX_PAT = "<你的 PAT>"
   npm run compile
   npm run publish:ovsx
   ```
   ```bash
   # macOS / Linux
   export OVSX_PAT="<你的 PAT>"
   npm run compile
   npm run publish:ovsx
   ```
   也可以直接发布已打好的包：`npx ovsx publish LiHui.trae-auto-checkin-<version>.vsix -p <你的 PAT>`
4. 发布后 2~3 分钟索引生效，可在 https://open-vsx.org/api/LiHui/trae-auto-checkin 查询。

## 许可证

MIT