# update-dev.ps1
# sxw-main: 拉代码 + build 镜像 + 更新容器
# wenfxl:   直接拉 Docker Hub 最新镜像 + 更新容器

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Log($msg)     { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor Cyan }
function Success($msg) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor Green }
function Err($msg)     { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $msg" -ForegroundColor Red; exit 1 }

Set-Location $ScriptDir

$currentBranch = git branch --show-current
Log "当前分支: $currentBranch"

# 如果有未提交改动先 stash
$hasChanges = (git status --porcelain) -ne ""
if ($hasChanges) {
    Log "检测到未提交改动，暂存中..."
    git stash push -m "update-dev-script-auto-stash"
    if ($LASTEXITCODE -ne 0) { Err "git stash 失败" }
}

# ─── 1. 更新 sxw 版本（从源码 build）───────────────────────────
Log ">>> [1/2] 切换到 sxw-main，拉取最新代码..."
git checkout sxw-main
if ($LASTEXITCODE -ne 0) { Err "切换 sxw-main 失败" }

git pull sxw713 main
if ($LASTEXITCODE -ne 0) { Err "拉取 sxw713/main 失败" }

Log "构建 sxw-codex:latest 镜像..."
docker build -f Dockerfile.dev -t sxw-codex:latest .
if ($LASTEXITCODE -ne 0) { Err "构建 sxw-codex 镜像失败" }
Success "sxw-codex:latest 构建完成"

# ─── 2. 更新 wenfxl 版本（直接拉 Docker Hub）────────────────────
Log ">>> [2/2] 拉取 wenfxl/wenfxl-codex-manager:latest 最新镜像..."
docker pull wenfxl/wenfxl-codex-manager:latest
if ($LASTEXITCODE -ne 0) { Err "拉取 wenfxl Docker Hub 镜像失败（请检查网络）" }
Success "wenfxl/wenfxl-codex-manager:latest 拉取完成"

# ─── 3. 还原分支和 stash ─────────────────────────────────────────
Log "还原分支到 $currentBranch..."
git checkout $currentBranch

if ($hasChanges) {
    Log "还原暂存的改动..."
    git stash pop
}

# ─── 4. 重启两个容器 ─────────────────────────────────────────────
Log "重启容器..."
docker compose -f docker-compose.dev.yml up -d --force-recreate
if ($LASTEXITCODE -ne 0) { Err "容器启动失败" }

Success "全部完成！"
Write-Host ""
Write-Host "  你的版本 (sxw-main)  -> http://localhost:8001" -ForegroundColor Yellow
Write-Host "  上游版本 (wenfxl)    -> http://localhost:8000" -ForegroundColor Yellow
