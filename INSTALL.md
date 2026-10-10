# Trae Auto Checkin 安装说明（其他机器）

## 0. 前置条件

| 条件 | 说明 |
|------|------|
| 系统 | **Windows**（插件读取 `%APPDATA%\Trae CN` 下的登录凭证，macOS / Linux 暂不支持） |
| IDE | 已安装 **Trae CN** 或 **TRAE SOLO CN** |
| 登录 | 该机器上 Trae CN **已登录账号**（未登录会提示「未检测到 Trae CN」） |

只需下载一个文件即可安装：`LiHui.trae-auto-checkin-1.0.4.vsix`（约 11 KB，跨平台通用包）。

## 1. 下载链接

- **Open VSX 直链**
  ```
  https://open-vsx.org/api/LiHui/trae-auto-checkin/1.0.4/file/LiHui.trae-auto-checkin-1.0.4.vsix
  ```
- **插件主页**：https://open-vsx.org/extension/LiHui/trae-auto-checkin
- **GitHub Release**（含源码）：https://github.com/zzxzr/trae-auto-checkin/releases/tag/v1.0.4

命令行下载（PowerShell）：
```powershell
Invoke-WebRequest -Uri "https://open-vsx.org/api/LiHui/trae-auto-checkin/1.0.4/file/LiHui.trae-auto-checkin-1.0.4.vsix" -OutFile "$env:USERPROFILE\Downloads\LiHui.trae-auto-checkin-1.0.4.vsix"
```

---

## 方式一：Trae CN 界面安装（最简单）

1. 打开 Trae CN
2. `Ctrl+Shift+X` 打开扩展面板
3. 点击面板右上角 `···` → **从 VSIX 安装...**（Install from VSIX...）
4. 选择下载好的 `LiHui.trae-auto-checkin-1.0.4.vsix`
5. 右下角提示安装成功后，**重启 Trae CN**

---

## 方式二：Trae 命令行安装

打开 PowerShell，执行（把路径换成你实际的 vsix 路径）：

```powershell
& "$env:LOCALAPPDATA\Programs\Trae CN\bin\trae-cn.cmd" --install-extension "$env:USERPROFILE\Downloads\LiHui.trae-auto-checkin-1.0.4.vsix" --force
```

看到 `was successfully installed.` 即成功，**重启 Trae CN**。

如果提示找不到 `trae-cn.cmd`，先确认 Trae CN 安装位置，再把命令换成实际路径，例如：
```powershell
& "D:\Trae CN\bin\trae-cn.cmd" --install-extension "...vsix" --force
```

---

## 方式三：install 脚本安装（自动定位 + 清理旧版本）

把 `LiHui.trae-auto-checkin-1.0.4.vsix` 和仓库里的 `install/` 目录放在同一层：

```
某个目录\
├── LiHui.trae-auto-checkin-1.0.4.vsix
└── install\
    ├── install.bat
    ├── install.ps1
    └── install.sh
```

Windows：**双击 `install.bat`**；或在 PowerShell 中执行：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\install\install.ps1"
```

脚本会自动完成：查找 vsix → 查找 Trae CN 命令行 → 安装（找不到命令行时自动解压到 `~/.trae-cn/extensions/lihui.trae-auto-checkin-1.0.4`）→ 清理同名旧版本。

macOS / Linux（仅安装，功能仍需 Windows）：
```bash
chmod +x install/install.sh && ./install/install.sh
```

---

## 2. 验证是否装好

1. 重启 Trae CN
2. `Ctrl+Shift+X` 搜索 `Trae Auto Checkin`，应显示已安装、版本 1.0.4
3. `Ctrl+Shift+P` 输入 `Trae Checkin`，能看到两条命令：
   - `Trae Checkin: 立即签到`
   - `Trae Checkin: 查看签到状态与积分`
4. 执行后会弹提示或在输出面板 `Trae Auto Checkin` 中看到 device_id、积分、签到结果

默认启动 IDE 后延迟 5 秒自动签到，可在设置中调整 `traeAutoCheckin.*` 三项配置。

## 3. 卸载

```powershell
& "$env:LOCALAPPDATA\Programs\Trae CN\bin\trae-cn.cmd" --uninstall-extension LiHui.trae-auto-checkin
```

## 4. 常见问题

| 现象 | 原因 / 处理 |
|------|-------------|
| 双击 vsix 弹出「适用于 Visual Studio Code…」报错 | 双击会用 VS Code 的安装器。请改用上面的方式一 / 二 / 三 |
| 提示「未检测到 Trae CN」 | 该机器没装 Trae CN，或没登录过账号；插件只在 Windows 生效 |
| 扩展面板搜不到 | Trae CN 国行走自有市场，Open VSX 上架不会自动同步，用 vsix 安装即可 |
| 更新到新版 | 重新下载新 vsix，用方式二加 `--force` 覆盖安装，或方式三脚本自动清理旧版本 |
