<div align="center">

# Velpos

**封装 AI Agent — 身份、SOP、工具集于一身，基于 Claude Code 构建。**

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB.svg?logo=python&logoColor=white)](https://www.python.org/)
[![Vue](https://img.shields.io/badge/Vue-3-4FC08D.svg?logo=vuedotjs&logoColor=white)](https://vuejs.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688.svg?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Claude](https://img.shields.io/badge/Claude_Code-Agent_SDK-D97757.svg)](https://github.com/anthropics/claude-code-sdk-python)

[中文文档](./README_zh.md)&ensp;|&ensp;[Demo Video](https://www.bilibili.com/video/BV1iEDhBuEVZ/)&ensp;|&ensp;[License](./LICENSE)&ensp;|&ensp;[Code of Conduct](./CODE_OF_CONDUCT.md)

</div>

<br/>

Velpos 是一个基于 [Agent SDK](https://github.com/anthropics/claude-code-sdk-python) 构建的 [Claude Code](https://github.com/anthropics/claude-code) Web 控制台。其核心价值在于**Agent 封装**——将可复用的 AI 助手封装成可配置单元，在可视化界面背后整合**身份定义**、**插件驱动的 SOP** 和**工具访问**。

这让**非技术用户**能够更轻松地构建和运营多 Agent AI 助手——无需手写提示词、无需手动连接工具、无需脆弱的命令链。

<br/>

## 目录

- [为什么需要 Agent 封装](#为什么需要-agent-封装)
- [核心亮点](#核心亮点)
- [部署](#部署)
  - [开发环境](#开发环境)
  - [生产环境](#生产环境)
- [首次运行设置](#首次运行设置)
- [使用概览](#使用概览)
- [架构](#架构)
- [技术栈](#技术栈)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

<br/>

## 为什么需要 Agent 封装

大多数 AI 助手设置最终都会崩溃，因为真正的运营知识分散在提示词、工具权限、插件配置和各种未文档化的工作流程习惯中。

Velpos 将这些变动部件封装成可复用的形式：

| 层级 | 功能 |
|---|---|
| **身份** | 定义 Agent 是什么、扮演什么角色、应该如何行为 |
| **SOP** | 编码可重复的工作流程，让 Agent 遵循稳定的过程——而非临时提示 |
| **工具** | 通过插件暴露正确的能力——最终用户无需自行组装工具链 |
| **复用** | 跨项目、团队和场景应用相同的封装 Agent，减少偏差 |

这对于**产品负责人、支持人员、领域专家或创始人**——这些需要成果而非提示词工程的人——尤为有用。

<br/>

## 核心亮点

### Agent 封装

- **封装式 Agent**——将身份、角色边界和行为期望捆绑成可复用单元
- **插件驱动的 SOP**——通过插件将可重复的工作流程转化为稳定的操作程序
- **工具封装**——隐藏底层工具连接，使最终用户在任务级别工作
- **多 Agent 协作**——组合封装式 Agent，实现专业角色、交接和团队工作流程

### 平台能力

- **项目工作区**——按目录组织会话，拥有隔离的 Claude Code 工作区
- **流式聊天**——实时 WebSocket，支持 Markdown 渲染和代码高亮
- **内置终端**——在当前项目目录下运行命令
- **插件管理**——安装/卸载 Claude Code MCP 插件
- **记忆管理**——通过 UI 编辑 `CLAUDE.md` 和记忆文件
- **Git 管理**——配置身份和 SSH 密钥
- **IM 集成**——连接 Lark、微信、QQ、OpenIM 实现双向同步
- **渠道配置**——管理多个 API 密钥、主机和模型映射
- **设置中心**——在一处管理 Claude Code 核心设置

<br/>

## 部署

```bash
git clone git@github.com:Jxin-Cai/velpos.git
cd velpos
```

### 开发环境

> 仅 MySQL 运行在 Docker 中。后端和前端运行在**宿主机**上，直接管理**宿主机文件系统**路径。

**前置条件：** Node.js >= 18, Python >= 3.11, Docker, [uv](https://docs.astral.sh/uv/), Claude Code CLI (`claude` 在 PATH 中)

**1. 配置**

```bash
cp build/dev/.env.example build/dev/.env
```

所有开发设置都在这个文件中。`CLAUDE_CLI_PATH` 在启动时**自动检测**——无需手动设置，除非 `claude` 安装在非标准位置。

<details>
<summary><b>build/dev/.env</b></summary>

| 变量 | 默认值 | 描述 |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | `root123456` | MySQL root 密码 |
| `MYSQL_DATABASE` | `velpos` | 数据库名 |
| `MYSQL_HOST_PORT` | `3307` | 暴露给宿主机的 MySQL 端口 |
| `DATABASE_URL` | `mysql+aiomysql://root:root123456@localhost:3307/velpos` | 后端数据库连接（必须与上述 MySQL 设置匹配） |
| `BACKEND_PORT` | `8083` | 后端端口 |
| `FRONTEND_PORT` | `3000` | 前端端口 |
| `CLAUDE_CLI_PATH` | *(自动检测)* | 仅在 `claude` 不在 PATH 中时覆盖 |
| `CLAUDE_PERMISSION_MODE` | `acceptEdits` | 默认权限模式 |
| `DEFAULT_MODEL` | `claude-opus-4-6` | 默认模型 |
| `PROJECTS_ROOT_DIR` | `~/claude-projects` | **宿主机文件系统**上的项目根目录 |
| `CORS_ALLOW_ORIGINS` | `*` | 允许的浏览器来源 |

</details>

**2. 启动**

```bash
build/dev/start.sh start
```

这将启动 MySQL（Docker）、后端（宿主机上的 `uv run uvicorn`）和前端（宿主机上的 `npm run dev`）。数据库迁移在后端启动时自动运行。

| 服务 | URL |
|---|---|
| 前端 | http://localhost:3000 |
| API 文档 | http://localhost:8083/docs |

<details>
<summary><b>服务管理</b></summary>

```bash
build/dev/start.sh start     # 启动所有
build/dev/start.sh stop      # 停止所有
build/dev/start.sh restart   # 重启所有
build/dev/start.sh status    # 显示状态
build/dev/start.sh logs      # 跟踪后端日志
```

</details>

### 生产环境

> 所有服务运行在 Docker 中（MySQL + 后端 + 前端/nginx）。后端管理**容器内部**的文件。通过主机目录绑定挂载来持久化项目数据。

**1. 配置**

```bash
cp build/prod/.env.example build/prod/.env
```

<details>
<summary><b>build/prod/.env — 一站式配置</b></summary>

| 变量 | 默认值 | 描述 |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | — | MySQL root 密码 |
| `MYSQL_DATABASE` | `velpos` | 数据库名 |
| `APP_PORT` | `80` | nginx 暴露的公共端口 |
| `PROJECTS_HOST_DIR` | `~/.agent_projects` | 挂载到容器内 `/data/projects` 的宿主机目录 |
| `ANTHROPIC_API_KEY` | — | Anthropic API 密钥 |
| `CLAUDE_PERMISSION_MODE` | `acceptEdits` | 默认权限模式 |
| `DEFAULT_MODEL` | `claude-opus-4-6` | 默认模型 |

以下由 docker-compose **自动配置**，无需设置：

| 变量 | 固定值 | 原因 |
|---|---|---|
| `DATABASE_URL` | `mysql+aiomysql://root:...@mysql:3306/velpos` | 容器间网络 |
| `CLAUDE_CLI_PATH` | `/usr/local/bin/claude` | 安装在后端镜像中 |
| `PROJECTS_ROOT_DIR` | `/data/projects` | 容器内部挂载点 |

</details>

**2. 构建并启动**

```bash
cd build/prod
docker compose up --build -d
```

包含 MySQL、后端和前端（nginx）。通过 `http://localhost`（或你配置的端口）访问 UI。

<br/>

## 首次运行设置

> **重要：** 启动服务后，必须在 Web UI 中配置设置，Claude Code 会话才能工作。

**1.** 点击顶部栏的**齿轮图标**打开设置。

**2.** 创建**渠道配置**（API 端点 + 密钥 + 模型映射）：

&emsp;&emsp;添加渠道 &#8594; 填写名称、主机、API 密钥 &#8594; 创建 &#8594; 激活

**3.** 查看**设置配置**：

<details>
<summary><b>可用设置</b></summary>

| 设置 | 描述 |
|---|---|
| **Permission Mode** | 默认 / 接受编辑 / 计划 / 绕过 |
| **Completed Onboarding** | 跳过入门 UI |
| **Effort Level** | 低 / 中 / 高推理努力 |
| **Skip Dangerous Mode Prompt** | 跳过绕过模式的额外确认 |
| **Disable Non-Essential Traffic** | 禁用非核心网络流量 |
| **Agent Teams** | 实验性多 Agent 支持 |
| **Tool Search** | 启用 MCP 工具搜索和动态加载 |
| **Attribution** | 配置提交和 PR 的归属文本 |

</details>

**4.** 创建项目，创建会话，**加载你的封装 Agent**，开始工作。

<br/>

## 使用概览

| 区域 | 可执行操作 |
|---|---|
| **项目与会话** | 从侧边栏创建项目，指向本地目录，管理会话 |
| **聊天** | 发送提示词、粘贴/拖拽图片、查看带代码高亮的流式 Markdown |
| **模型与权限** | 从顶部栏切换模型，选择权限模式以控制自主性 |
| **终端** | 打开内置终端，在项目目录下运行命令 |
| **插件与 Agent** | 安装 MCP 插件，加载项目级封装 Agent |
| **记忆** | 直接在 UI 中编辑 `CLAUDE.md` 和记忆文件 |
| **Git** | 管理全局 Git 身份和 SSH 密钥 |
| **IM 集成** | 将会话绑定到 **Lark**、**微信**、**QQ** 或 **OpenIM** 实现双向同步 |

<br/>

## 架构

```text
velpos/
├── backend/                  # Python FastAPI
│   ├── domain/               # 领域层——纯业务逻辑
│   ├── application/          # 应用服务——用例编排
│   ├── infr/                 # 基础设施——仓库、客户端、适配器
│   ├── ohs/                  # 开放主机服务——REST + WebSocket
│   └── alembic/              # 数据库迁移
├── frontend/                 # Vue 3 + Vite
│   └── src/
│       ├── app/              # 壳、路由、引导
│       ├── pages/            # 路由级页面
│       ├── features/         # 隔离的 UI 功能
│       ├── entities/         # 核心业务数据
│       └── shared/           # 工具、HTTP/WS 客户端
└── build/
    ├── dev/                  # 开发：Docker MySQL + 宿主机服务
    └── prod/                 # 生产：完整 Docker 栈
```

后端遵循**DDD 四层**架构。前端采用**特性切片**结构。

<br/>

## 技术栈

| 层级 | 技术 |
|---|---|
| 后端 | Python, FastAPI, SQLAlchemy (async), Alembic, Claude Agent SDK, aiomysql |
| 前端 | Vue 3, Vite, marked, highlight.js |
| 数据库 | MySQL 8 |
| 包管理 | uv (后端), npm (前端) |

<br/>

## 贡献指南

参与之前请阅读[行为准则](./CODE_OF_CONDUCT.md)。

如果你计划贡献重大变更，**请先提交 issue** 讨论方向和范围。我们欢迎错误报告、功能请求和拉取请求。

## 许可证

根据 [Apache License 2.0](./LICENSE) 授权。

版权所有 2026 jxin
