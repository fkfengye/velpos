# Windows + uv Python 3.12 下 claude_agent_sdk 子进程启动失败

## 1. 问题描述

### 1.1 问题概述

调用 `/api/sessions/meta/models` 接口时返回 500 错误，日志持续抛出 `CLIConnectionError: Failed to start Claude Code: NotImplementedError`。WebSocket 连接成功后，Claude 查询也报同样错误，导致前端无法正常使用 Claude Code 功能。

### 1.2 受影响接口

| 序号 | 接口地址 | 错误现象 |
|------|----------|----------|
| 1 | `GET /api/sessions/meta/models` | 500 Internal Server Error |
| 2 | Claude 查询（WebSocket） | Claude查询失败 |

### 1.3 问题等级

**高危**

---

## 2. 问题分析

### 2.1 技术原理

Python 3.12 在 Windows 上有两套事件循环实现：

| 事件循环 | Windows 支持 | subprocess 支持 |
|---------|------------|----------------|
| `SelectorEventLoop` | ✅ 支持 | ❌ 不支持 |
| `ProactorEventLoop` | ✅ 支持 | ✅ 支持 |

`claude_agent_sdk` 底层使用 `anyio.open_process()` 启动 Claude CLI 子进程，该函数内部调用 `asyncio.create_subprocess_exec()`。在 Windows + Python 3.12 环境下，默认的 `SelectorEventLoop` 的 subprocess 相关方法未实现，抛出 `NotImplementedError`。

### 2.2 根因分析

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 平台 | Windows 11 | 触发条件 |
| Python 版本 | 3.12.13 (uv) | 根因环境 |
| uvicorn --reload | 启用 | 导致 use_subprocess=True |
| 事件循环 | SelectorEventLoop | 不支持 subprocess |
| claude_agent_sdk | 最新版 | 使用 anyio 启动子进程 |

**根因结论：**
uvicorn 的 `--reload` 标志会导致 `use_subprocess=True`，进而使 uvicorn 在 Windows 上使用 `SelectorEventLoop`。但 Windows + Python 3.12 的 `SelectorEventLoop` 的 subprocess 相关方法未实现，抛出 `NotImplementedError`，导致 claude_agent_sdk 无法启动 Claude CLI 子进程。

**uvicorn 源码关键逻辑（config.py:361-362）：**
```python
@property
def use_subprocess(self) -> bool:
    return bool(self.reload or self.workers > 1)
```
```python
# loops/asyncio.py:8-11
def asyncio_loop_factory(use_subprocess: bool = False) -> Callable[[], asyncio.AbstractEventLoop]:
    if sys.platform == "win32" and not use_subprocess:
        return asyncio.ProactorEventLoop  # 支持 subprocess
    return asyncio.SelectorEventLoop  # use_subprocess=True 时返回这个
```

### 2.3 数据流追踪

```
HTTP Request (GET /api/sessions/meta/models)
    ↓
FastAPI Route (session_router.py:90 list_models)
    ↓
SessionApplicationService.get_models()
    ↓
ClaudeAgentGateway.get_models()
    ↓
ClaudeSDKClient.connect()
    ↓
anyio.open_process()  ← 失败点
    ↓
asyncio.create_subprocess_exec()
    ↓
SelectorEventLoop._make_subprocess_transport()
    ↓
NotImplementedError  ← Windows 不支持
```

---

## 3. 修复方案

### 3.1 方案选型

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **移除 --reload 标志** | 根本解决问题，uvicorn 会自动使用 ProactorEventLoop | 开发时需手动重启服务 | **推荐** |
| 在 main.py 设置事件循环策略 | 可保留 --reload | 可能有其他副作用 | 备选 |
| 降级 uvicorn | 可保留 --reload | 可能有其他兼容性问题 | 备选 |

### 3.2 实施步骤

#### 步骤一：修改 build/dev/start.sh

**文件路径：** `build/dev/start.sh`

移除 uvicorn 启动命令中的 `--reload` 标志：

```diff
- nohup uv run uvicorn main:app \
-     --host 0.0.0.0 \
-     --port "$BACKEND_PORT" \
-     --reload \
-     --log-level info \
+ nohup uv run uvicorn main:app \
+     --host 0.0.0.0 \
+     --port "$BACKEND_PORT" \
+     --log-level info \
```

#### 步骤二：修改 build/dev/start-local.sh

**文件路径：** `build/dev/start-local.sh`

移除 uvicorn 启动命令中的 `--reload` 标志（修改内容同上）。

#### 步骤三：修改 build/dev/start-win.ps1

**文件路径：** `build/dev/start-win.ps1`

移除 uvicorn 启动命令中的 `--reload` 标志：

```diff
- Start-Process -FilePath "uv" `
-     -ArgumentList "run uvicorn main:app --host 0.0.0.0 --port $backendPort --reload --log-level info" `
+ Start-Process -FilePath "uv" `
+     -ArgumentList "run uvicorn main:app --host 0.0.0.0 --port $backendPort --log-level info" `
```

### 3.3 改动说明

| 改动项 | 说明 |
|--------|------|
| 改动位置 | `build/dev/start.sh`、`build/dev/start-local.sh`、`build/dev/start-win.ps1` |
| 影响范围 | 三个开发环境启动脚本均受影响 |
| 副作用 | 开发时修改代码后需手动重启后端服务 |
| 兼容性 | Linux/Mac 不受影响 |

### 3.4 部署验证

重启后端服务，访问以下接口验证：

- `GET /api/sessions/meta/models` — 应返回 200 和模型列表
- WebSocket 连接并发送消息 — 应正常建立 Claude 查询会话

预期结果：不再出现 `NotImplementedError` 和 `CLIConnectionError`。

---

## 4. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2026-04-14 | 1.0 | 初始问题分析与修复方案 | Claude |
| 2026-04-14 | 1.1 | 移除所有开发启动脚本（start.sh、start-local.sh、start-win.ps1）中的 --reload 标志，避免 uvicorn 在 Windows 上使用 SelectorEventLoop | Claude |
| 2026-04-14 | 1.2 | 验证修复有效，问题已解决 | Claude |

---

## 5. 参考资料

- [Python asyncio - Windows Event Loop](https://docs.python.org/3/library/asyncio-platforms.html#asyncio.WindowsProactorEventLoopPolicy)
- [anyio - Subprocess](https://anyio.readthedocs.io/en/stable/subprocesses.html)
- [claude-agent-sdk](https://github.com/anthropics/claude-agent-sdk)
