# -*- coding: utf-8 -*-
# 五笔86·拼音 输入方案 一键安装（PowerShell 版，零 Python 依赖）
# 适用于已安装小狼毫（Weasel）的 Windows 电脑：复制方案与词库 -> 配置 schema 列表 -> 部署 -> 重启服务

$ErrorActionPreference = "Stop"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
$RIME_USER = Join-Path $env:APPDATA "Rime"
$SCHEMA_ID = "wubi86py"

function Write-Step($msg) { Write-Host "== $msg" -ForegroundColor Cyan }

# ---------- 1. 探测小狼毫安装目录 ----------
function Find-WeaselDir {
    $keys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel",
        "HKLM:\SOFTWARE\Rime\Weasel",
        "HKCU:\Software\Rime\Weasel"
    )
    foreach ($k in $keys) {
        if (Test-Path $k) {
            $root = (Get-ItemProperty $k -ErrorAction SilentlyContinue).WeaselRoot
            if ($root -and (Test-Path (Join-Path $root "WeaselServer.exe"))) { return $root }
        }
    }
    $scans = Get-ChildItem "C:\Program Files\Rime" -Directory -Filter "weasel-*" -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending
    foreach ($d in $scans) {
        if (Test-Path (Join-Path $d.FullName "WeaselServer.exe")) { return $d.FullName }
    }
    return $null
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  五笔86·拼音 输入方案 一键安装" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

$WEASEL = Find-WeaselDir
if (-not $WEASEL) {
    Write-Host "[错误] 未找到小狼毫（Weasel）安装目录。" -ForegroundColor Red
    Write-Host "       请先安装小狼毫：https://github.com/rime/weasel/releases" -ForegroundColor Yellow
    exit 1
}
Write-Step "小狼毫目录: $WEASEL"

# ---------- 2. 复制方案文件与词库 ----------
$FILES = @("wubi86py.schema.yaml", "wubi86py.dict.yaml",
           "wubi86py.term.dict.yaml", "wubi86py.term.schema.yaml")
foreach ($f in $FILES) {
    $src = Join-Path $HERE $f
    if (-not (Test-Path $src)) { Write-Host "[错误] 缺少文件: $src" -ForegroundColor Red; exit 1 }
    Copy-Item $src (Join-Path $RIME_USER $f) -Force
}
Write-Step "已复制方案与码表（4 个文件）-> $RIME_USER"

$luaDir = Join-Path $RIME_USER "lua"
New-Item -ItemType Directory -Force $luaDir | Out-Null
$LUA_FILES = @("wubi86py_commit.lua", "fr_comment.lua", "fr_pos.lua", "fr_data.lua")
foreach ($f in $LUA_FILES) {
    $src = Join-Path $HERE $f
    if (-not (Test-Path $src)) { Write-Host "[错误] 缺少文件: $src" -ForegroundColor Red; exit 1 }
    Copy-Item $src (Join-Path $luaDir $f) -Force
}
Write-Step "已复制 Lua 词库与处理器（4 个文件）-> $RIME_USER\lua"

# ---------- 3. 把方案加入 schema 列表（先备份） ----------
$cfg = Join-Path $RIME_USER "default.custom.yaml"
$entry = "- schema: $SCHEMA_ID         # 五笔86 · 拼音辅助（独立编制）"
if (Test-Path $cfg) {
    $text = [IO.File]::ReadAllText($cfg)
    if ($text -match "schema: $SCHEMA_ID") {
        Write-Step "default.custom.yaml 已包含本方案，跳过配置"
    } else {
        $bak = "$cfg.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        Copy-Item $cfg $bak
        Write-Step "已备份原配置: $(Split-Path $bak -Leaf)"
        $lines = $text -split "`r?`n"
        $out = [System.Collections.Generic.List[string]]::new()
        $inserted = $false
        foreach ($line in $lines) {
            $out.Add($line)
            if (-not $inserted -and $line.TrimStart().StartsWith("schema_list:")) {
                $indent = $line.Substring(0, $line.Length - $line.TrimStart().Length)
                $out.Add("$indent  $entry")
                $inserted = $true
            }
        }
        if (-not $inserted) {
            $out.Add("")
            $out.Add("patch:")
            $out.Add("  schema_list:")
            $out.Add("    $entry")
        }
        [IO.File]::WriteAllText($cfg, ($out -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding $false))
        Write-Step "已把 wubi86py 加入 schema_list 首位"
    }
} else {
    New-Item -ItemType Directory -Force (Split-Path $cfg) | Out-Null
    [IO.File]::WriteAllText($cfg, "patch:`r`n  schema_list:`r`n    $entry`r`n", (New-Object Text.UTF8Encoding $false))
    Write-Step "已创建 default.custom.yaml 并加入本方案"
}

# ---------- 4. 重启服务并部署 ----------
Write-Step "重启小狼毫服务"
Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process (Join-Path $WEASEL "WeaselServer.exe")
Start-Sleep -Seconds 2

$deployer = Join-Path $WEASEL "WeaselDeployer.exe"
if (Test-Path $deployer) {
    Write-Step "编译部署（librime）..."
    & $deployer /deploy | Out-Null
    # 轮询等待编译产物生成（首次全量编译需 1 分钟左右）
    $t1 = Join-Path $RIME_USER "build\wubi86py.table.bin"
    $t2 = Join-Path $RIME_USER "build\wubi86py.term.table.bin"
    $deadline = (Get-Date).AddSeconds(120)
    while (((-not (Test-Path $t1)) -or (-not (Test-Path $t2))) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
    }
    if ((Test-Path $t1) -and (Test-Path $t2)) {
        Write-Step "编译产物已生成，部署完成"
    } else {
        Write-Host "[提示] 编译产物尚未生成，请右键托盘小狼毫图标 -> 重新部署" -ForegroundColor Yellow
    }
} else {
    Write-Host "[提示] 未找到 WeaselDeployer.exe，请右键托盘小狼毫图标 -> 重新部署" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "== 安装完成 ==" -ForegroundColor Green
Write-Host "使用方法："
Write-Host "  1. 在任意输入框按 Ctrl+Shift 切换到小狼毫输入法"
Write-Host "  2. 若方案未出现：右键托盘小狼毫图标 -> 重新部署，再按 Ctrl+` 切换"
Write-Host "  3. 五笔输入（如 trnt=我）；打不出五笔直接输拼音（如 wo=我）"
Write-Host "  4. 候选右侧显示法语注释；空格=中文上屏，回车=原码上屏，Tab=法语上屏"
Write-Host "  5. 卸载：双击 一键卸载.bat"
