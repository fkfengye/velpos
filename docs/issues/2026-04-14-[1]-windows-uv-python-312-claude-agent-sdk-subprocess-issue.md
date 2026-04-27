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

### 2.4 事件循环与 I/O 模型详解

#### 2.4.1 两种 I/O 模型对比

| 模型 | 核心思想 | 事件循环 | 代表系统 |
|------|----------|----------|----------|
| **Reactor（反应器）** | "你问我，我告诉你" | SelectorEventLoop | Linux (epoll)、macOS (kqueue) |
| **Proactor（主动器）** | "我做完了，通知你" | ProactorEventLoop | Windows (IOCP) |

**Reactor 模式的工作流程：**
```python
while True:
    ready_fds = selector.select()  # 阻塞询问：谁准备好了？
    for fd in ready_fds:
        callback(fd)  # 通知应用处理
```

**Proactor 模式的工作流程：**
```python
while True:
    completion = iocp.poll()  # 内核直接通知：这事完成了
    callback(completion.result)  # 应用获取结果
```

#### 2.4.2 为什么 Windows subprocess 与 SelectorEventLoop 不兼容

| 组件 | SelectorEventLoop | ProactorEventLoop |
|------|------------------|-------------------|
| 底层机制 | `select()` 系统调用 | Windows IOCP |
| 支持的 fd 类型 | 仅支持 socket | 支持 socket、管道、文件等 |
| subprocess 管道 | ❌ 不支持 | ✅ 支持 |

**根本原因：**
- Windows 的 `select()` 只支持 socket，不支持管道
- subprocess 需要监控 stdin/stdout/stderr 管道
- 所以 `SelectorEventLoop._make_subprocess_transport()` 直接抛出 `NotImplementedError`

#### 2.4.3 修复后的运行机制

**移除 `--reload` 后的效果：**

| 配置 | 事件循环 | subprocess | velpos 功能 |
|------|----------|-----------|------------|
| `--reload` | `SelectorEventLoop` | ❌ NotImplementedError | HTTP/WebSocket 正常，Claude CLI 异常 |
| 无 `--reload` | `ProactorEventLoop` | ✅ 正常 | 所有功能正常 |

**对 velpos 来说，SelectorEventLoop 和 ProactorEventLoop 的效果是否一样？**

对于 velpos 的业务逻辑，**效果完全一样**。两种事件循环都提供：

- 异步 HTTP 请求处理
- WebSocket 连接管理
- 数据库异步操作
- 定时器、任务调度

**唯一的区别是 subprocess 支持：**

| 功能 | SelectorEventLoop | ProactorEventLoop |
|------|------------------|-------------------|
| 网络 I/O | ✅ | ✅ |
| 文件 I/O | ✅ | ✅ |
| subprocess | ❌ Windows 上不支持 | ✅ Windows 上支持 |
| 定时器 | ✅ | ✅ |

所以移除 `--reload` 后，velpos 的所有功能正常工作，Claude CLI subprocess 也能正常启动了。

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
| 2026-04-14 | 1.1 | 在 main.py 顶部添加 Windows 事件循环策略设置（无效，已回退） | Claude |
| 2026-04-14 | 1.2 | 分析 uvicorn 源码，发现 --reload 与 use_subprocess 的关系 | Claude |
| 2026-04-14 | 1.3 | 移除 start.sh 中的 --reload 标志 | Claude |
| 2026-04-14 | 1.4 | 发现 start-local.sh 和 start-win.ps1 也需要修改 | Claude |
| 2026-04-14 | 1.5 | 三个启动脚本全部修改完成，验证修复有效，main.py 回退修改 | Claude |

---

## 5. 调试分析过程

### 5.1 第一次尝试（失败）

**假设：** 直接在 `main.py` 顶部设置 `WindowsProactorEventLoopPolicy` 即可解决问题。

**修改：** `backend/main.py`
```python
import asyncio
import sys

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())
```

**结果：** 重启后问题依旧，错误依旧为 `NotImplementedError`。

**分析：** `asyncio.set_event_loop_policy()` 设置的是"默认策略"，但 uvicorn 创建事件循环时有其他逻辑覆盖了这个设置。最终此修改被回退（见变更记录 1.5）。

### 5.2 深入调查：直接测试 subprocess

**验证：** 在 uv Python 环境中直接测试 asyncio subprocess：
```python
import asyncio
asyncio.run(asyncio.create_subprocess_exec('echo', 'hello'))
# 结果：成功！
```

这说明 **asyncio subprocess 本身是正常的**，问题出在 uvicorn 的事件循环选择上。

### 5.3 关键发现：uvicorn 的 use_subprocess 逻辑

**源码分析：**

1. `uvicorn/config.py`:
```python
@property
def use_subprocess(self) -> bool:
    return bool(self.reload or self.workers > 1)
```

2. `uvicorn/loops/asyncio.py`:
```python
def asyncio_loop_factory(use_subprocess: bool = False):
    if sys.platform == "win32" and not use_subprocess:
        return asyncio.ProactorEventLoop
    return asyncio.SelectorEventLoop
```

**推论：**
- `--reload` → `use_subprocess=True` → `SelectorEventLoop` → subprocess 失败
- 无 `--reload` → `use_subprocess=False` → `ProactorEventLoop` → subprocess 正常

### 5.4 第二次尝试：移除 --reload

**修改：** 移除所有启动脚本中的 `--reload` 标志

**结果：** 第一次修复只改了 `start.sh`，但日志显示 uvicorn 仍在使用 WatchFiles reload 机制。

**再分析：** 发现三个启动脚本：
- `start.sh` — 第一个被修改
- `start-local.sh` — 也需要修改
- `start-win.ps1` — Windows 用户实际使用的脚本

**最终修复：** 三个脚本全部移除 `--reload` 后，问题解决。

### 5.5 调试方法总结

| 步骤 | 方法 | 结论 |
|------|------|------|
| 1 | 直接测试 asyncio subprocess | asyncio 本身正常 |
| 2 | 分析 uvicorn 源码 | 发现 `--reload` 影响事件循环选择 |
| 3 | 对比三个启动脚本 | 确认所有脚本都需要修改 |
| 4 | 验证修复结果 | subprocess 正常工作 |

---

## 6. 参考资料

- [Python asyncio - Windows Event Loop](https://docs.python.org/3/library/asyncio-platforms.html#asyncio.WindowsProactorEventLoopPolicy)
- [anyio - Subprocess](https://anyio.readthedocs.io/en/stable/subprocesses.html)
- [claude-agent-sdk](https://github.com/anthropics/claude-agent-sdk)
- [asyncio 事件循环与 Windows subprocess 原理分析](./2026-04-14-[2]-asyncio-event-loop-windows-subprocess-analysis.md)
