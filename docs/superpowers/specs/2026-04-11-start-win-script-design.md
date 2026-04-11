# start-win.ps1 设计文档

## 背景

将 `build/dev/start.sh` 移植为 Windows 原生启动脚本，不依赖 Docker，MySQL 直接使用用户已有的数据库实例。

## 目标

- Windows PowerShell 5.1+ 兼容
- 移除所有 Docker 依赖
- 保持与原 `start.sh` 一致的命令接口和用户体验

## 设计

### 命令接口

| 命令 | 功能 |
|------|------|
| `.\start-win.ps1 start` | 启动后端 + 前端，追踪后端日志 |
| `.\start-win.ps1 stop` | 停止后端 + 前端（不操作 MySQL） |
| `.\start-win.ps1 restart` | 重启全部 |
| `.\start-win.ps1 status` | 查看服务状态 |
| `.\start-win.ps1 logs` | 追踪后端日志 |

### 与原脚本的差异

| 项目 | 原 `start.sh` | 新 `start-win.ps1` |
|------|---------------|---------------------|
| MySQL | Docker 启动并管理 | **不管理**，假设已存在 |
| 后端 | `uv run uvicorn` | 同 |
| 前端 | `npm run dev` | 同 |
| 进程管理 | PID 文件 + `kill` | 按端口号查找进程并停止 |
| 日志追踪 | `tail -f` | `Get-Content -Wait -Tail 50` |
| 健康检查 | `curl -sf` | `Invoke-WebRequest` |
| PID 文件 | 有 | **移除**（Windows 端口查找更可靠） |

### 进程启动方式

```powershell
# 后端
Start-Process -FilePath "uv" `
    -ArgumentList "run uvicorn main:app --host 0.0.0.0 --port $BackendPort --reload --log-level info" `
    -WorkingDirectory $BackendDir `
    -NoNewWindow `
    -PassThru

# 前端
Start-Process -FilePath "npm" `
    -ArgumentList "run dev -- --host 0.0.0.0" `
    -WorkingDirectory $FrontendDir `
    -NoNewWindow `
    -PassThru
```

### 停止进程方式

按端口号查找并终止（不依赖 PID 文件）：

```powershell
# 按端口查进程 PID
$pid = (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).OwningProcess | Select-Object -First 1
if ($pid) { Stop-Process -Id $pid -Force }
```

### 预检查

1. **.env 文件**：从 `build/dev/.env` 读取环境变量
2. **MySQL 连接检查**：`Test-NetConnection -Port 3306` 验证 MySQL 可达
3. **端口占用检查**：启动前检查 8083/3000 是否被占用

### 日志文件

- 后端日志：`$ROOT_DIR\.logs\backend.log`
- 前端日志：`$ROOT_DIR\.logs\frontend.log`

### 目录结构

```
build/dev/
├── start.sh       # 原 Unix 脚本
└── start-win.ps1  # 新增 Windows 脚本
```

## 实现要点

- 使用 `StrictMode` 避免隐式错误
- 颜色输出通过 `Write-Host` + ANSI 转义序列（PowerShell 5.1+ 支持）
- 日志文件目录不存在时自动创建
- 停止时不操作 MySQL（用户自行管理）
