# SETUP.md — Velpos 设置指南（适用于 Claude Code）

本文件指导 Claude Code 完成 Velpos 开发环境的设置。
按顺序遵循每个部分。需要选择时，请询问用户。

## 前提条件检查

开始前，验证这些工具已安装。如果缺少任何工具，请安装它们。

> **注意：** 对于**生产模式**（完整 Docker），只需要 Docker — Python、uv、Node.js 和 Claude CLI 都会在容器内自动安装。以下前提条件（2-5 节）仅在**开发模式**下需要。

### 1. Docker 和 Docker Compose

```bash
# 检查是否已安装
docker --version && docker compose version
```

**如果缺失，请安装：**
- macOS：`brew install --cask docker`（或从 https://www.docker.com/products/docker-desktop/ 下载 Docker Desktop）
- Linux（Ubuntu/Debian）：
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  ```

### 2. Python 3.11+

```bash
python3 --version  # 必须 >= 3.11
```

**如果缺失，请安装：**
- macOS：`brew install python@3.12`
- Linux：`sudo apt install python3.12 python3.12-venv`

### 3. uv（Python 包管理器）

```bash
uv --version
```

**如果缺失，请安装：**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 4. Node.js 22+ 和 npm

```bash
node --version  # 必须 >= 22
npm --version
```

**如果缺失，请安装：**
- macOS：`brew install node@22`
- Linux：
  ```bash
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt install -y nodejs
  ```
- 或使用 nvm：`nvm install 22`

### 5. Claude Code CLI

```bash
claude --version
```

**如果缺失，请安装：**
```bash
npm install -g @anthropic-ai/claude-code
```

安装后，运行一次 `claude` 完成身份验证。

---

## 环境设置

**询问用户：** "您想要设置**开发**（本地开发）还是**生产**（Docker 生产）？"

### 选项 A：开发模式

开发模式在 Docker 中运行 MySQL，在宿主机上运行后端和前端。

#### 步骤 1：复制环境文件

```bash
cp build/dev/.env.example build/dev/.env
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

#### 步骤 2：配置环境

编辑 `build/dev/.env`：
- `CLAUDE_CLI_PATH` — 设置为 `which claude` 的输出
- `MYSQL_ROOT_PASSWORD` — 如有需要可以更改
- `PROJECTS_ROOT_DIR` — 存储用户项目的目录（默认：`~/claude-projects`）

编辑 `backend/.env`：
- `DATABASE_URL` — 必须与上面设置的 MySQL 密码匹配。格式：`mysql+aiomysql://root:<password>@localhost:3307/velpos`
- `CLAUDE_CLI_PATH` — 与上述相同

#### 步骤 3：安装依赖

```bash
# 后端 Python 依赖
cd backend && uv sync && cd ..

# 前端 Node 依赖
cd frontend && npm install && cd ..
```

#### 步骤 4：启动所有服务

```bash
build/dev/start.sh start
```

这将启动 MySQL（Docker）、后端（端口 8083）和前端（端口 3000）。

**验证：**
- 前端：http://localhost:3000
- 后端 API：http://localhost:8083/docs
- 健康检查：`curl http://localhost:8083/api/health`

#### 开发服务管理

```bash
build/dev/start.sh stop      # 停止所有服务
build/dev/start.sh restart   # 重启所有服务
build/dev/start.sh status    # 检查状态
build/dev/start.sh logs      # 尾随后端日志
```

---

### 选项 B：生产模式（完整 Docker）

生产模式在 Docker 容器中运行所有服务（MySQL + 后端 + 前端/nginx）。
Claude Code CLI 会**在后端容器内自动安装** — 无需在宿主机上安装，也无需从宿主机映射。

#### 步骤 1：复制环境文件

```bash
cp build/prod/.env.example build/prod/.env
```

#### 步骤 2：配置环境

编辑 `build/prod/.env`：
- `MYSQL_ROOT_PASSWORD` — 使用强密码
- `ANTHROPIC_API_KEY` — 您的 Anthropic API 密钥（生产环境必需，由容器内的 Claude CLI 使用）
- `APP_PORT` — 要暴露的宿主机端口（默认：80）
- `PROJECTS_HOST_DIR` — 项目文件的宿主机目录（默认：`~/.agent_projects`）

#### 步骤 3：构建并启动

```bash
cd build/prod && docker compose up --build -d
```

**验证：**
- 应用程序：http://localhost（或自定义 `APP_PORT`）
- 日志：`cd build/prod && docker compose logs -f`

#### 停止

```bash
cd build/prod && docker compose down
```

---

## 端口汇总

| 服务    | 开发         | 生产            |
|---------|--------------|-----------------|
| 前端    | 3000         | 80（nginx）     |
| 后端    | 8083         | 8083（内部）    |
| MySQL   | 3307（宿主机）| 3306（内部）    |

## 故障排除

- **后端无法启动**：检查 `backend/.env` 中的 `DATABASE_URL` 是否与 MySQL 凭据匹配
- **Claude 查询失败**：验证 `CLAUDE_CLI_PATH` 指向有效的 `claude` 二进制文件，且 `claude` 已通过身份验证
- **端口冲突**：更改 `build/dev/.env` 中的端口，或终止冲突进程
- **MySQL 连接被拒绝**：在 `start.sh start` 后等待几秒钟，或运行 `docker ps` 确保 MySQL 容器正在运行
