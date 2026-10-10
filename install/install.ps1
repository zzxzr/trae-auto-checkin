<#
.SYNOPSIS
    把 Trae Auto Checkin 插件安装到 Trae CN IDE（Windows）。

.DESCRIPTION
    优先使用 Trae CN 自带的命令行工具安装：
        trae-cn.cmd --install-extension <xxx.vsix> --force
    若找不到命令行工具，则退化为直接解压 vsix 到扩展目录：
        %USERPROFILE%\.trae-cn\extensions\lihui.trae-auto-checkin-<version>
    安装前会清理同名插件的历史版本目录，避免重复加载。

.EXAMPLE
    .\install.ps1
    .\install.ps1 -VsixPath "D:\soft\lihui.trae-auto-checkin-1.0.4.vsix"
    .\install.ps1 -NoCli      # 强制使用解压方式
#>
param(
    [string]$VsixPath,
    [switch]$NoCli
)

$ErrorActionPreference = 'Stop'

$Publisher = 'LiHui'                        # 与 Open VSX 命名空间一致
$Name      = 'trae-auto-checkin'
$ExtId     = "$Publisher.$Name"
$DirId     = $ExtId.ToLower()               # IDE 扩展目录使用小写 id

function Write-Step([string]$Message) {
    Write-Host "[install] $Message" -ForegroundColor Cyan
}
function Write-Ok([string]$Message) {
    Write-Host "[install] $Message" -ForegroundColor Green
}

# ---------- 1. 定位 vsix ----------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $VsixPath) {
    foreach ($dir in @($scriptDir, (Split-Path -Parent $scriptDir), (Get-Location).Path)) {
        if (-not $dir) { continue }
        $hit = Get-ChildItem -Path (Join-Path $dir "*trae-auto-checkin-*.vsix") -File -ErrorAction SilentlyContinue |
               Sort-Object Name -Descending | Select-Object -First 1
        if ($hit) { $VsixPath = $hit.FullName; break }
    }
}
if (-not $VsixPath -or -not (Test-Path -LiteralPath $VsixPath)) {
    throw "找不到 $ExtId-<version>.vsix，请把 vsix 放到脚本目录，或用 -VsixPath 指定。"
}
$VsixPath = (Resolve-Path -LiteralPath $VsixPath).Path
Write-Step "使用插件包: $VsixPath"

# ---------- 2. 解析版本与目标目录名 ----------
$vsixName = [System.IO.Path]::GetFileNameWithoutExtension($VsixPath)   # lihui.trae-auto-checkin-1.0.4
$version  = ($vsixName -split '-')[-1]
if ($version -notmatch '^\d+(\.\d+)*$') { $version = '0.0.0' }
$targetDirName = "$DirId-$version"

# ---------- 3. 扩展根目录 ----------
$extRoot = Join-Path $HOME '.trae-cn\extensions'
if (-not (Test-Path -LiteralPath $extRoot)) {
    $alt = Join-Path $HOME '.trae\extensions'
    if (Test-Path -LiteralPath $alt) { $extRoot = $alt }
}
New-Item -ItemType Directory -Path $extRoot -Force | Out-Null
Write-Step "扩展目录: $extRoot"

# ---------- 4. 清理历史版本（publisher.name 必须完全一致） ----------
Get-ChildItem -Path $extRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'trae-auto-checkin-\d' -and $_.Name -ne $targetDirName } |
    ForEach-Object {
        Write-Step "删除历史版本: $($_.Name)"
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

# ---------- 5. 查找 Trae CN 命令行工具 ----------
$cli = $null
if (-not $NoCli) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Trae CN\bin\trae-cn.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Trae CN\bin\trae-cn'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Trae\bin\trae.cmd'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Trae CN\Trae CN.exe')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { $cli = $c; break }
    }
    if (-not $cli) {
        $inPath = Get-Command trae-cn -ErrorAction SilentlyContinue
        if ($inPath) { $cli = $inPath.Source }
    }
}

# ---------- 6. 安装 ----------
if ($cli) {
    Write-Step "使用 Trae 命令行安装: $cli"
    & $cli --install-extension $VsixPath --force
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "安装完成（$targetDirName）。请重启 Trae CN IDE 生效。"
        exit 0
    }
    Write-Warning "命令行安装失败（退出码 $LASTEXITCODE），改用解压方式安装。"
}

$tmp = Join-Path $env:TEMP ("trae-ext-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zipPath = Join-Path $tmp 'package.zip'
    Copy-Item -LiteralPath $VsixPath -Destination $zipPath -Force
    Expand-Archive -LiteralPath $zipPath -DestinationPath $tmp -Force
    $src = Join-Path $tmp 'extension'
    if (-not (Test-Path -LiteralPath $src)) { throw 'vsix 内缺少 extension 目录，安装包可能损坏。' }
    $dest = Join-Path $extRoot $targetDirName
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Move-Item -LiteralPath $src -Destination $dest -Force
    Write-Ok "已解压安装到: $dest"
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Ok '安装完成。请重启 Trae CN IDE，命令面板搜索 “Trae Checkin: 立即签到” 即可使用。'
