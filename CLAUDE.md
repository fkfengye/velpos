# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 项目概述

Velpos 是一个通过 Agent SDK 控制 Claude Code 的 Web 界面。Python FastAPI 后端 + Vue 3 前端，通过 REST 和 WebSocket 进行通信。

## 开发命令

### 快速启动（开发环境）
```bash
# 1. 复制并配置环境变量
cp build/dev/.env.example build/dev/.env

# 2. 启动所有服务（MySQL docker + 后端 + 前端）
build/dev/start.sh start
```

### 开发服务管理
```bash
build/dev/start.sh start     # 启动 MySQL + 后端 + 前端，跟踪日志
build/dev/start.sh stop      # 停止所有（包括 MySQL）
build/dev/start.sh restart   # 重启所有
build/dev/start.sh status    # 查看运行状态
build/dev/start.sh logs      # 跟踪后端日志
```

### 生产环境（完整 Docker）
```bash
# 1. 配置
cp build/prod/.env.example build/prod/.env

# 2. 构建并启动
cd build/prod && docker compose up --build -d
```

### 单独运行服务
```bash
# 后端（从 backend/ 目录）
uv run uvicorn main:app --host 0.0.0.0 --port 8083 --reload

# 前端（从 frontend/ 目录）
npm run dev
npm run build
```

### 构建目录结构
```
build/
├── dev/                  # 开发：Docker MySQL + 宿主机后端/前端
│   ├── docker-compose.yml
│   ├── .env.example
│   └── start.sh
└── prod/                 # 生产：完整 Docker 栈
    ├── docker-compose.yml
    ├── backend.Dockerfile
    ├── frontend.Dockerfile
    ├── nginx.conf
    └── .env.example
```

### 端口
- 后端：8083（API 文档位于 http://localhost:8083/docs）
- 前端：3000（开发）/ 80（生产，通过 nginx）
- MySQL：3307（开发宿主机）/ 3306（生产内部）

### 数据库迁移（Alembic）
```bash
# 从 backend/ 目录执行
uv run alembic revision --autogenerate -m "description"
uv run alembic upgrade head
```
迁移在后端启动时自动运行。如果 Alembic 失败则回退到 `create_all`。

### 必需的环境变量
- `DATABASE_URL` — 缺少此变量后端无法启动（抛出 RuntimeError）
- `CLAUDE_CLI_PATH` — claude CLI 二进制文件的路径

## 后端架构 — DDD 四层

```
backend/
├── domain/           # 纯业务逻辑，无框架依赖
│   ├── session/      # Session 聚合：Session、Message、Usage、Status
│   ├── project/      # Project 聚合
│   ├── im_binding/   # IM 渠道绑定，渠道注册表
│   ├── channel_profile/
│   └── shared/       # 跨域值对象
├── application/      # 用例编排（每个聚合一个服务）
│   ├── session/      # SessionApplicationService + commands
│   ├── project/      # ProjectApplicationService + commands
│   ├── im_binding/   # ImChannelApplicationService
│   ├── channel_profile/ claude_session/ command/ plugin/ settings/ terminal/
│   └── (每个都有 command/ 用于输入 DTO，有些有 port/ 用于 ABC 接口)
├── infr/             # 基础设施实现
│   ├── config/       # database.py (SQLAlchemy async), im_config.py, base.py
│   ├── repository/   # *RepositoryImpl + SQLAlchemy ORM 模型 + Alembic 迁移
│   ├── client/       # ClaudeAgentGateway、ConnectionManager 等
│   └── im/           # IM 适配器：lark/、openim/、qq/、weixin/
└── ohs/              # 开放主机服务——外部-facing 层
    ├── dependencies.py  # DI 组装（FastAPI Depends），单例接线
    ├── http/            # REST 路由、ApiResponse<T>、DTO、装配器
    └── ws/              # WebSocket 路由（/ws/{session_id}）
```

### 关键模式
- **DI 接线**：`ohs/dependencies.py` 在模块级别创建单例，并提供 `get_*` 工厂函数供 FastAPI `Depends` 使用。
- **领域 ACL**：领域定义抽象接口（如 `domain/session/acl/claude_agent_gateway.py`），基础设施层实现它们。
- **命令**：应用层使用冻结的 Pydantic 模型作为输入 DTO（如 `CreateSessionCommand`）。
- **装配器**：`ohs/assembler/` 在领域模型和 HTTP DTO 之间进行转换。
- **API 响应**：统一的 `ApiResponse(code, message, data)` —— code 0 表示成功。
- **WebSocket 协议**：`/ws/{session_id}`，基于动作的消息（`send_prompt`、`cancel`、`get_status`、`set_model`、`set_permission_mode`、`user_response`）和基于事件的响应（`connected`、`message`、`status_change`、`error`、`info`）。
- **IM 集成**：插件式适配器注册在 `ImChannelRegistry`（Lark、OpenIM、QQ、微信）。通过回调钩子在助手响应时同步出站。

## 前端架构 — Vue 3 + 特性切片

```
frontend/src/
├── app/        # 应用壳（App.vue、main.js、router）
├── pages/      # 路由级页面（chat-panel/）
├── features/   # 自包含的 UI 特性
│   ├── session-list/    send-message/    message-display/
│   ├── cancel-query/    clear-context/   compact-context/
│   ├── command-palette/  plugin-manager/  settings-manager/
│   ├── im-binding/      terminal/        notification-center/
├── entities/   # 核心业务数据（session/、project/）
└── shared/     # 共享工具（api/、components/、styles/）
```

### 关键模式
- **状态管理**：模块级单例组合式函数（`useSession.js`、`useProject.js`）——不用 Pinia/Vuex。
- **HTTP 客户端**：`shared/api/httpClient.js` —— 将 `code === 0` 视为成功。
- **WS 客户端**：`shared/api/wsClient.js` —— 异常关闭时自动重连。
- **路径别名**：`@app`、`@pages`、`@features`、`@entities`、`@shared`、`@`（→ `src/`）。
- **无组件库**——全程使用自定义 CSS。

## 技术栈
- **后端**：Python 3.11+、FastAPI、SQLAlchemy (async)、Alembic、claude-agent-sdk、aiomysql
- **前端**：Vue 3（组合式 API）、Vite 8、marked、highlight.js
- **数据库**：MySQL 8
- **包管理**：uv（后端）、npm（前端）
