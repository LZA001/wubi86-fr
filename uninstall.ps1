# -*- coding: utf-8 -*-
# 五笔86·拼音 输入方案 一键卸载（PowerShell 版，零 Python 依赖）
# 移除方案专属文件与配置项并重新部署；fr_comment/fr_pos/fr_data 为共享词库，保留不删

$ErrorActionPreference = "Stop"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
$RIME_USER = Join-Path $env:APPDATA "Rime"
$SCHEMA_ID = "wubi86py"

function Write-Step($msg) { Write-Host "== $msg" -ForegroundColor Cyan }

Write-Host ""
Write-Host "== 五笔86·拼音 输入方案 卸载 ==" -ForegroundColor Green

# ---------- 1. 从 schema 列表移除 ----------
$cfg = Join-Path $RIME_USER "default.custom.yaml"
if (Test-Path $cfg) {
    $text = [IO.File]::ReadAllText($cfg)
    if ($text -match "schema: $SCHEMA_ID") {
        $bak = "$cfg.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        Copy-Item $cfg $bak
        Write-Step "已备份原配置: $(Split-Path $bak -Leaf)"
        $lines = $text -split "`r?`n" | Where-Object { $_ -notmatch "^\s*- \{\s*schema: $SCHEMA_ID\s*\}" -and $_ -notmatch "^\s*- schema: $SCHEMA_ID\b" }
        [IO.File]::WriteAllText($cfg, ($lines -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding $false))
        Write-Step "已从 schema_list 移除 wubi86py"
    } else {
        Write-Step "default.custom.yaml 未包含本方案，跳过"
    }
}

# ---------- 2. 删除方案专属文件（共享词库保留） ----------
$FILES = @("wubi86py.schema.yaml", "wubi86py.dict.yaml",
           "wubi86py.term.dict.yaml", "wubi86py.term.schema.yaml")
foreach ($f in $FILES) {
    $p = Join-Path $RIME_USER $f
    if (Test-Path $p) { Remove-Item $p -Force; Write-Step "已删除 $f" }
}
$luaShared = Join-Path $RIME_USER "lua\wubi86py_commit.lua"
if (Test-Path $luaShared) { Remove-Item $luaShared -Force; Write-Step "已删除 lua\wubi86py_commit.lua（本方案专属）" }

$buildDir = Join-Path $RIME_USER "build"
foreach ($f in @("wubi86py.schema.yaml", "wubi86py.prism.bin", "wubi86py.table.bin",
                 "wubi86py.reverse.bin", "wubi86py.term.schema.yaml",
                 "wubi86py.term.prism.bin", "wubi86py.term.table.bin", "wubi86py.term.reverse.bin")) {
    $p = Join-Path $buildDir $f
    if (Test-Path $p) { Remove-Item $p -Force; Write-Step "已删除编译产物 $f" }
}

# ---------- 3. 重启服务并部署 ----------
$WEASEL = $null
$keys = @("HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel", "HKLM:\SOFTWARE\Rime\Weasel", "HKCU:\Software\Rime\Weasel")
foreach ($k in $keys) {
    if (Test-Path $k) { $WEASEL = (Get-ItemProperty $k -ErrorAction SilentlyContinue).WeaselRoot; if ($WEASEL) { break } }
}
if (-not $WEASEL) {
    $scans = Get-ChildItem "C:\Program Files\Rime" -Directory -Filter "weasel-*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
    if ($scans) { $WEASEL = $scans[0].FullName }
}

Write-Step "重启小狼毫服务"
Stop-Process -Name WeaselServer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if ($WEASEL -and (Test-Path (Join-Path $WEASEL "WeaselServer.exe"))) {
    Start-Process (Join-Path $WEASEL "WeaselServer.exe")
    Start-Sleep -Seconds 2
}
$deployer = Join-Path $WEASEL "WeaselDeployer.exe"
if ($WEASEL -and (Test-Path $deployer)) {
    Write-Step "重新部署..."
    & $deployer /deploy | Out-Null
    Start-Sleep -Seconds 10
}

Write-Host ""
Write-Host "== 卸载完成 ==" -ForegroundColor Green
Write-Host "fr_data.lua / fr_pos.lua / fr_comment.lua 为共享法语词库，已保留（frime 等方案仍可用）"
