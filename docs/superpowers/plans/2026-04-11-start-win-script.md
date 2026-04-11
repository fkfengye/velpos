# start-win.ps1 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 创建 `build/dev/start-win.ps1`，在 Windows 上启动后端 + 前端服务，不依赖 Docker。

**架构：** PowerShell 5.1+ 兼容脚本，通过端口号管理进程（查找 + 停止），使用 `Start-Process` 后台启动 `uvicorn` 和 `npm run dev`。

**技术栈：** PowerShell 原生，无第三方依赖。

---

## Task 1: 编写 start-win.ps1 脚本

**文件：**
- 创建: `build/dev/start-win.ps1`

### Step 1: 确认 .env 文件路径

检查 `build/dev/.env` 是否存在。如果不存在，脚本报错退出：

```powershell
$scriptDir = $PSScriptRoot
$envFile = Join-Path $scriptDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "[ERROR] .env file not found at $envFile" -ForegroundColor Red
    Write-Host "Copy .env.example to .env first:" -ForegroundColor Yellow
    Write-Host "  cp build/dev/.env.example build/dev/.env" -ForegroundColor Gray
    exit 1
}
```

### Step 2: 读取环境变量

从 `.env` 解析键值对（支持 `#` 注释和空行）：

```powershell
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
}
```

### Step 3: 定义路径和常量

```powershell
$rootDir = Join-Path $scriptDir "../.."
$backendDir = Join-Path $rootDir "backend"
$frontendDir = Join-Path $rootDir "frontend"
$logDir = Join-Path $rootDir ".logs"

$backendPort = if ($env:BACKEND_PORT) { $env:BACKEND_PORT } else { "8083" }
$frontendPort = if ($env:FRONTEND_PORT) { $env:FRONTEND_PORT } else { "3000" }

$backendLog = Join-Path $logDir "backend.log"
$frontendLog = Join-Path $logDir "frontend.log"
```

### Step 4: 创建日志目录

```powershell
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
```

### Step 5: 定义日志辅助函数

```powershell
function Write-Info($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
```

### Step 6: 定义端口进程查找函数

```powershell
function Get-Process-By-Port($port) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $proc = Get-Process -Id $conn[0].OwningProcess -ErrorAction SilentlyContinue
        return $proc
    }
    return $null
}
```

### Step 7: 定义停止进程函数

```powershell
function Stop-By-Port($port, $name) {
    $proc = Get-Process-By-Port $port
    if ($proc) {
        Write-Info "Stopping $name (PID: $($proc.Id), Port: $port)..."
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Write-Ok "$name stopped"
    } else {
        Write-Info "$name is not running (port $port)"
    }
}
```

### Step 8: 定义健康检查函数

```powershell
function Test-Port($port, $timeoutSec = 30) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:$port/api/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($resp.StatusCode -eq 200 -or $resp.StatusCode -eq 404) { return $true }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    return $false
}
```

### Step 9: MySQL 连接检查（启动前预检）

```powershell
function Test-MySQL {
    Write-Info "Checking MySQL connection..."
    $mysqlHost = if ($env:DATABASE_URL -match '@([^:]+):(\d+)') { $matches[1] } else { "localhost" }
    $mysqlPort = if ($env:DATABASE_URL -match '@[^:]+:(\d+)') { $matches[1] } else { "3306" }

    $result = Test-NetConnection -ComputerName $mysqlHost -Port $mysqlPort -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        Write-Ok "MySQL is reachable at $mysqlHost`:$mysqlPort"
        return $true
    } else {
        Write-Err "MySQL is NOT reachable at $mysqlHost`:$mysqlPort"
        Write-Err "Please ensure MySQL is running before starting the backend."
        return $false
    }
}
```

### Step 10: do_start 函数

```powershell
function do_start {
    # ASCII banner
    Write-Host ""
    Write-Host "  __     __    _                  " -ForegroundColor Cyan
    Write-Host "  \ \   / /___| |_ __   ___  ___ " -ForegroundColor Cyan
    Write-Host "   \ \ / // _ \ | '_ \ / _ \/ __|" -ForegroundColor Cyan
    Write-Host "    \ V /|  __/ | |_) | (_) \__ \" -ForegroundColor Cyan
    Write-Host "     \_/  \___|_| .__/ \___/|___/" -ForegroundColor Cyan
    Write-Host "                |_|              " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [ DEV MODE - Windows ]" -ForegroundColor Yellow
    Write-Host ""

    # MySQL check
    if (-not (Test-MySQL)) {
        Write-Err "Cannot proceed without MySQL."
        exit 1
    }

    # Start backend
    $existingBackend = Get-Process-By-Port $backendPort
    if ($existingBackend) {
        Write-Warn "Backend already running (PID: $($existingBackend.Id))"
    } else {
        Write-Info "Starting backend on port $backendPort..."

        # Check uv is available
        $uvCheck = Get-Command uv -ErrorAction SilentlyContinue
        if (-not $uvCheck) {
            Write-Err "'uv' not found. Install uv: https://github.com/astral-sh/uv"
            exit 1
        }

        $proc = Start-Process -FilePath "uv" `
            -ArgumentList "run uvicorn main:app --host 0.0.0.0 --port $backendPort --reload --log-level info" `
            -WorkingDirectory $backendDir `
            -NoNewWindow `
            -PassThru `
            -RedirectStandardOutput $backendLog `
            -RedirectStandardError $backendLog

        Write-Info "Backend starting (PID: $proc.Id)..."

        if (Test-Port $backendPort 30) {
            Write-Ok "Backend started -> http://localhost:$backendPort"
        } else {
            Write-Err "Backend failed to start. Check logs: $backendLog"
            exit 1
        }
    }

    # Start frontend
    $existingFrontend = Get-Process-By-Port $frontendPort
    if ($existingFrontend) {
        Write-Warn "Frontend already running (PID: $($existingFrontend.Id))"
    } else {
        Write-Info "Starting frontend on port $frontendPort..."

        Start-Process -FilePath "npm" `
            -ArgumentList "run dev -- --host 0.0.0.0" `
            -WorkingDirectory $frontendDir `
            -NoNewWindow `
            -PassThru `
            -RedirectStandardOutput $frontendLog `
            -RedirectStandardError $frontendLog | Out-Null

        # Wait for frontend
        Start-Sleep 5
        $frontendReady = $false
        try {
            Invoke-WebRequest -Uri "http://localhost:$frontendPort" -TimeoutSec 5 -ErrorAction SilentlyContinue | Out-Null
            $frontendReady = $true
        } catch {}

        if ($frontendReady) {
            Write-Ok "Frontend started -> http://localhost:$frontendPort"
        } else {
            Write-Warn "Frontend may not be ready yet. Check: $frontendLog"
        }
    }

    Write-Host ""
    Write-Host "All services started!" -ForegroundColor Green
    Write-Host "  Frontend:  http://localhost:$frontendPort" -ForegroundColor White
    Write-Host "  Backend:   http://localhost:$backendPort" -ForegroundColor White
    Write-Host "  API Docs:  http://localhost:$backendPort/docs" -ForegroundColor White
    Write-Host ""
    Write-Host "Tailing backend logs... (Ctrl+C to detach)" -ForegroundColor Yellow
    Write-Host "---"

    # Tail logs
    if (Test-Path $backendLog) {
        Get-Content $backendLog -Wait -Tail 50
    } else {
        Write-Err "No backend log found."
    }
}
```

### Step 11: do_stop 函数

```powershell
function do_stop {
    Write-Info "Stopping all services..."
    Stop-By-Port $frontendPort "Frontend"
    Stop-By-Port $backendPort "Backend"
    Write-Ok "All services stopped"
}
```

### Step 12: do_restart 函数

```powershell
function do_restart {
    do_stop
    Start-Sleep 2
    do_start
}
```

### Step 13: do_status 函数

```powershell
function do_status {
    Write-Host "Service Status:" -ForegroundColor White
    Write-Host ""

    # MySQL
    $mysqlHost = if ($env:DATABASE_URL -match '@([^:]+):(\d+)') { $matches[1] } else { "localhost" }
    $mysqlPort = if ($env:DATABASE_URL -match '@[^:]+:(\d+)') { $matches[1] } else { "3306" }
    $mysqlOk = $false
    try {
        $result = Test-NetConnection -ComputerName $mysqlHost -Port $mysqlPort -WarningAction SilentlyContinue
        $mysqlOk = $result.TcpTestSucceeded
    } catch {}

    if ($mysqlOk) {
        Write-Host "  MySQL:     RUNNING -> $mysqlHost`:$mysqlPort" -ForegroundColor Green
    } else {
        Write-Host "  MySQL:     STOPPED or UNREACHABLE -> $mysqlHost`:$mysqlPort" -ForegroundColor Red
    }

    # Backend
    $backendProc = Get-Process-By-Port $backendPort
    if ($backendProc) {
        Write-Host "  Backend:   RUNNING (PID: $($backendProc.Id)) -> http://localhost:$backendPort" -ForegroundColor Green
    } else {
        Write-Host "  Backend:   STOPPED" -ForegroundColor Red
    }

    # Frontend
    $frontendProc = Get-Process-By-Port $frontendPort
    if ($frontendProc) {
        Write-Host "  Frontend:  RUNNING (PID: $($frontendProc.Id)) -> http://localhost:$frontendPort" -ForegroundColor Green
    } else {
        Write-Host "  Frontend:  STOPPED" -ForegroundColor Red
    }

    Write-Host ""
}
```

### Step 14: do_logs 函数

```powershell
function do_logs {
    if (-not (Test-Path $backendLog)) {
        Write-Err "No backend log found. Is the server running?"
        exit 1
    }
    Get-Content $backendLog -Wait -Tail 50
}
```

### Step 15: 命令入口

```powershell
switch ($args[0]) {
    "start"   { do_start }
    "stop"    { do_stop }
    "restart" { do_restart }
    "status"  { do_status }
    "logs"    { do_logs }
    default {
        Write-Host "Usage: .\start-win.ps1 {start|stop|restart|status|logs}"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  start    Start backend + frontend, tail backend logs"
        Write-Host "  stop     Stop backend + frontend"
        Write-Host "  restart  Restart all services"
        Write-Host "  status   Show service status"
        Write-Host "  logs     Tail backend logs"
        exit 1
    }
}
```

---

## 自检清单

- [ ] 脚本覆盖所有命令：start / stop / restart / status / logs
- [ ] 移除所有 Docker 依赖
- [ ] 使用端口查找进程，不依赖 PID 文件
- [ ] MySQL 连接预检查
- [ ] 颜色输出正常（PowerShell 支持 ANSI）
- [ ] 日志文件目录自动创建
- [ ] 启动后健康检查等待就绪
- [ ] 与原 `start.sh` 功能对等

---

## 执行方式

两个选项：

**1. Subagent-Driven（推荐）** — 每步由 subagent 执行，我中间审核

**2. Inline Execution** — 本 session 内批量执行，有检查点

帅帅，用哪种方式？
