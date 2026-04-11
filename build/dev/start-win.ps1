# Velpos - Dev Environment Startup Script for Windows
# Starts backend + frontend on the host machine (no Docker for backend/frontend)
#
# Usage:
#   .\start-win.ps1 start    # Start backend + frontend, tail backend logs
#   .\start-win.ps1 stop     # Stop backend + frontend
#   .\start-win.ps1 restart  # Restart all services
#   .\start-win.ps1 status   # Show service status
#   .\start-win.ps1 logs     # Tail backend logs

# =============================================================================
# Step 1: Confirm .env file exists
# =============================================================================
$scriptDir = $PSScriptRoot
$envFile = Join-Path $scriptDir ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "[ERROR] .env file not found at $envFile" -ForegroundColor Red
    Write-Host "Copy .env.example to .env first:" -ForegroundColor Yellow
    Write-Host "  cp build/dev/.env.example build/dev/.env" -ForegroundColor Gray
    exit 1
}

# =============================================================================
# Step 2: Read environment variables
# =============================================================================
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
}

# =============================================================================
# Step 3: Define paths and constants
# =============================================================================
$rootDir = Join-Path $scriptDir "../.."
$backendDir = Join-Path $rootDir "backend"
$frontendDir = Join-Path $rootDir "frontend"
$logDir = Join-Path $rootDir ".logs"

$backendPort = if ($env:BACKEND_PORT) { $env:BACKEND_PORT } else { "8083" }
$frontendPort = if ($env:FRONTEND_PORT) { $env:FRONTEND_PORT } else { "3000" }

$backendLog = Join-Path $logDir "backend.log"
$frontendLog = Join-Path $logDir "frontend.log"

# =============================================================================
# Step 4: Create log directory
# =============================================================================
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# =============================================================================
# Step 5: Define logging helper functions
# =============================================================================
function Write-Info($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# =============================================================================
# Step 6: Define port process lookup function
# =============================================================================
function Get-Process-By-Port($port) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        $proc = Get-Process -Id $conn[0].OwningProcess -ErrorAction SilentlyContinue
        return $proc
    }
    return $null
}

# =============================================================================
# Step 7: Define stop process function
# =============================================================================
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

# =============================================================================
# Step 8: Define health check function
# =============================================================================
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

# =============================================================================
# Step 9: MySQL connection check (pre-check before starting)
# =============================================================================
function Test-MySQL {
    Write-Info "Checking MySQL connection..."
    # DATABASE_URL format: mysql://admin:password@host:port/database
    if ($env:DATABASE_URL -match '@([^:]+):(\d+)') {
        $mysqlHost = $matches[1]
        $mysqlPort = $matches[2]
    } else {
        $mysqlHost = "localhost"
        $mysqlPort = "3306"
    }

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

# =============================================================================
# Step 10: do_start function
# =============================================================================
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

    # Auto-detect CLAUDE_CLI_PATH if not set
    if ([string]::IsNullOrEmpty($env:CLAUDE_CLI_PATH)) {
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            $env:CLAUDE_CLI_PATH = $claudeCmd.Source
            Write-Info "Auto-detected CLAUDE_CLI_PATH: $($env:CLAUDE_CLI_PATH)"
        } else {
            Write-Warn "claude CLI not found in PATH. Set CLAUDE_CLI_PATH in .env if needed."
        }
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

        Start-Process -FilePath "uv" `
            -ArgumentList "run uvicorn main:app --host 0.0.0.0 --port $backendPort --reload --log-level info" `
            -WorkingDirectory $backendDir `
            -NoNewWindow `
            -PassThru | Out-Null

        Write-Info "Backend starting..."

        if (Test-Port $backendPort 60) {
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

        # Start frontend: redirect all output to log file
        $cmd = "npm run dev -- --host 0.0.0.0 2>&1 >> `"$frontendLog`""
        Start-Process -FilePath "cmd" -ArgumentList "/c", $cmd -WorkingDirectory $frontendDir -NoNewWindow

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

# =============================================================================
# Step 11: do_stop function
# =============================================================================
function do_stop {
    Write-Info "Stopping all services..."
    Stop-By-Port $frontendPort "Frontend"
    Stop-By-Port $backendPort "Backend"
    Write-Ok "All services stopped"
}

# =============================================================================
# Step 12: do_restart function
# =============================================================================
function do_restart {
    do_stop
    Start-Sleep 2
    do_start
}

# =============================================================================
# Step 13: do_status function
# =============================================================================
function do_status {
    Write-Host "Service Status:" -ForegroundColor White
    Write-Host ""

    # MySQL
    if ($env:DATABASE_URL -match '@([^:]+):(\d+)') {
        $mysqlHost = $matches[1]
        $mysqlPort = $matches[2]
    } else {
        $mysqlHost = "localhost"
        $mysqlPort = "3306"
    }
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

# =============================================================================
# Step 14: do_logs function
# =============================================================================
function do_logs {
    if (-not (Test-Path $backendLog)) {
        Write-Err "No backend log found. Is the server running?"
        exit 1
    }
    Get-Content $backendLog -Wait -Tail 50
}

# =============================================================================
# Step 15: Command entry point
# =============================================================================
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
