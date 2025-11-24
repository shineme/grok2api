# Grok2API

基于 **FastAPI** 重构的 Grok2API，全面适配最新 Web 调用格式，支持流式对话、图像生成、图像编辑、联网搜索、深度思考，号池并发与自动负载均衡一体化。


<br>

## 使用说明

### 调用次数与配额

- **普通账号（Basic）**：免费使用 **80 次 / 20 小时**
- **Super 账号**：配额待定（作者未测）
- 系统自动负载均衡各账号调用次数，可在**管理页面**实时查看用量与状态

### 图像生成功能

- 在对话内容中输入如“给我画一个月亮”自动触发图片生成
- 每次以 **Markdown 格式返回两张图片**，共消耗 4 次额度
- **注意：Grok 的图片直链受 403 限制，系统自动缓存图片到本地。必须正确设置 `Base Url` 以确保图片能正常显示！**

### 视频生成功能
- 选择 `grok-imagine-0.9` 模型，传入图片和提示词即可（方式和 OpenAI 的图片分析调用格式一致）
- 返回格式为 `<video src="{full_video_url}" controls="controls"></video>`
- **注意：Grok 的视频直链受 403 限制，系统自动缓存图片到本地。必须正确设置 `Base Url` 以确保视频能正常显示！**

```
curl https://你的服务器地址/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GROK2API_API_KEY" \
  -d '{
    "model": "grok-imagine-0.9",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "让太阳升起来"
          },
          {
            "type": "image_url",
            "image_url": {
              "url": "https://your-image.jpg"
            }
          }
        ]
      }
    ]
  }'
```

### 关于 `x_statsig_id`

- `x_statsig_id` 是 Grok 用于反机器人的 Token，有逆向资料可参考
- **建议新手勿修改配置，保留默认值即可**
- 尝试用 Camoufox 绕过 403 自动获 id，但 grok 现已限制非登陆的`x_statsig_id`，故弃用，采用固定值以兼容所有请求

<br>

## 如何运行环境

### 方式一：本地开发运行（推荐用于开发调试）

**前置要求：**
- Python 3.11 或更高版本
- pip 包管理器

**步骤：**

1. **克隆项目**
```bash
git clone <repository-url>
cd grok2api
```

2. **创建虚拟环境**
```bash
python3 -m venv .venv
source .venv/bin/activate  # Linux/macOS
# 或
.venv\Scripts\activate  # Windows
```

3. **安装依赖**
```bash
pip install -r requirements.txt
```

4. **配置环境变量（可选）**
```bash
# 创建 .env 文件（可选）
export STORAGE_MODE=file  # 可选：file, mysql, redis
# export DATABASE_URL=mysql://user:password@host:3306/grok2api  # MySQL/Redis 时需要
```

5. **启动服务**
```bash
# 方式1：使用 uvicorn 直接运行（推荐，支持热重载）
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# 方式2：使用 Python 运行主文件（端口 8001）
python main.py
```

6. **访问服务**
- 使用方式1（端口 8000）：
  - API 文档：http://localhost:8000/docs
  - 管理后台：http://localhost:8000/login
  - 健康检查：http://localhost:8000/health
- 使用方式2（端口 8001）：
  - API 文档：http://localhost:8001/docs
  - 管理后台：http://localhost:8001/login
  - 健康检查：http://localhost:8001/health

**注意事项：**
- 默认管理员账号：`admin` / `admin`（首次登录后建议修改）
- 本地运行不包含 WARP 代理，如需代理请配置 `proxy_url`
- 配置文件位于 `data/setting.toml`
- Token 数据存储在 `data/token.json`（file 模式）

<br>

### 方式二：Docker Compose 运行（推荐用于生产部署）

**前置要求：**
- Docker
- Docker Compose

**步骤：**

1. **创建 `docker-compose.yml` 文件**

```yaml
services:
  grok2api:
    image: ghcr.io/chenyme/grok2api:latest
    ports:
      - "8000:8000"
    volumes:
      - grok_data:/app/data
      - ./logs:/app/logs
    environment:
      # =====存储模式: file, mysql 或 redis=====
      - STORAGE_MODE=file
      # =====数据库连接 URL (仅在STORAGE_MODE=mysql或redis时需要)=====
      # - DATABASE_URL=mysql://user:password@host:3306/grok2api

      ## MySQL格式: mysql://user:password@host:port/database
      ## Redis格式: redis://host:port/db 或 redis://user:password@host:port/db (SSL: rediss://)
    # WARP 网络代理支持 - 自动安装并启动
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv4.ip_forward=1

volumes:
  grok_data:
```

2. **启动服务**
```bash
docker-compose up -d
```

3. **查看日志**
```bash
docker-compose logs -f
```

4. **停止服务**
```bash
docker-compose down
```

<br>

### 方式三：Docker 运行

**步骤：**

1. **拉取镜像**
```bash
docker pull ghcr.io/chenyme/grok2api:latest
```

2. **运行容器**
```bash
docker run -d \
  --name grok2api \
  -p 8000:8000 \
  -v grok_data:/app/data \
  -v ./logs:/app/logs \
  -e STORAGE_MODE=file \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv4.ip_forward=1 \
  ghcr.io/chenyme/grok2api:latest
```

<br>

### 方式四：从源码构建 Docker 镜像

**步骤：**

1. **构建镜像**
```bash
docker build -t grok2api:custom .
```

2. **运行容器**
```bash
docker run -d \
  --name grok2api \
  -p 8000:8000 \
  -v grok_data:/app/data \
  -v ./logs:/app/logs \
  -e STORAGE_MODE=file \
  --cap-add NET_ADMIN \
  --cap-add SYS_ADMIN \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv4.ip_forward=1 \
  grok2api:custom
```

<br>

## GitHub Actions 自动构建 Docker 镜像

项目已配置 GitHub Actions 自动化工作流，可以自动构建和发布 Docker 镜像到 GitHub Container Registry (ghcr.io)。

### 工作流触发条件

工作流会在以下情况自动触发：

1. **推送到 main 分支**：自动构建并推送 `latest` 标签
2. **推送版本标签**（如 `v1.0.0`）：自动构建并推送对应版本标签
3. **Pull Request**：仅构建镜像但不推送（用于验证）

### 支持的架构

自动构建支持多架构镜像：
- **linux/amd64**：适用于 x86_64 服务器和 PC
- **linux/arm64**：适用于 ARM 服务器（如 AWS Graviton）

### 镜像标签说明

| 触发条件 | 生成的标签 | 说明 |
|---------|-----------|------|
| 推送到 main | `ghcr.io/用户名/仓库名:latest` | 最新主分支版本（多架构） |
| 推送到 main | `ghcr.io/用户名/仓库名:main` | 主分支版本（多架构） |
| 推送标签 v1.2.3 | `ghcr.io/用户名/仓库名:v1.2.3` | 指定版本（多架构） |
| 推送标签 v1.2.3 | `ghcr.io/用户名/仓库名:1.2.3` | 指定版本（多架构） |

### 工作流配置文件

工作流配置位于：`.github/workflows/docker.yml`

**主要特性：**
- ✅ 多架构构建（amd64 + arm64）
- ✅ 自动推送到 GitHub Container Registry
- ✅ 构建缓存加速
- ✅ 自动版本标签管理
- ✅ 合并多架构镜像为统一标签

### 如何使用自动构建

#### 方法一：推送到 main 分支（构建 latest）

```bash
# 提交代码并推送到 main 分支
git add .
git commit -m "更新代码"
git push origin main

# GitHub Actions 会自动构建并推送镜像
# 镜像地址: ghcr.io/用户名/仓库名:latest
```

#### 方法二：创建版本标签（发布特定版本）

```bash
# 创建并推送版本标签
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions 会自动构建并推送镜像
# 镜像地址: ghcr.io/用户名/仓库名:v1.0.0
#         ghcr.io/用户名/仓库名:1.0.0
```

### 查看构建状态

1. 访问 GitHub 仓库的 **Actions** 标签页
2. 查看 "Build Docker Image" 工作流的运行状态
3. 点击具体的运行实例查看详细日志

### 拉取自动构建的镜像

```bash
# 拉取最新版本
docker pull ghcr.io/用户名/仓库名:latest

# 拉取特定版本
docker pull ghcr.io/用户名/仓库名:v1.0.0

# 拉取特定架构（可选）
docker pull --platform linux/amd64 ghcr.io/用户名/仓库名:latest
docker pull --platform linux/arm64 ghcr.io/用户名/仓库名:latest
```

### 权限配置

GitHub Actions 使用内置的 `GITHUB_TOKEN` 自动进行身份验证，无需额外配置 secrets。如果需要推送到其他镜像仓库（如 Docker Hub），可以添加相应的 secrets：

1. 进入仓库 **Settings** → **Secrets and variables** → **Actions**
2. 添加需要的 secrets（如 `DOCKERHUB_USERNAME` 和 `DOCKERHUB_TOKEN`）
3. 修改 `.github/workflows/docker.yml` 添加 Docker Hub 登录步骤

<br>

### WARP 网络代理自动安装

Docker 镜像已内置自动安装和启动 **Cloudflare WARP** 网络代理功能：

- **自动安装**：容器启动时自动检测并安装 WARP 客户端
- **自动连接**：服务启动前自动连接 WARP 网络
- **透明代理**：通过 WARP 为所有出站连接提供隐私保护和加速

**WARP 配置说明：**

| 配置项 | 说明 |
|--------|------|
| `cap_add: NET_ADMIN, SYS_ADMIN` | WARP 运行所需的 Linux 容器能力 |
| `net.ipv6.conf.all.disable_ipv6=0` | 启用 IPv6 支持（WARP 使用） |
| `net.ipv4.ip_forward=1` | 启用 IPv4 转发 |

**禁用 WARP（可选）：**

如不需要 WARP 代理，可使用自己的 Docker 镜像或修改启动脚本。
自动检测机制确保即使未安装 WARP，应用仍能正常运行。

### 环境变量说明

| 环境变量      | 必填 | 说明                                    | 示例 |
|---------------|------|-----------------------------------------|------|
| STORAGE_MODE  | 否   | 存储模式：file/mysql/redis               | file |
| DATABASE_URL  | 否   | 数据库连接URL（MySQL/Redis模式时必需）   | mysql://user:pass@host:3306/db |

**存储模式：**
- `file`: 本地文件存储（默认）
- `mysql`: MySQL数据库存储，需设置DATABASE_URL
- `redis`: Redis缓存存储，需设置DATABASE_URL

<br>

## 接口说明

> 与 OpenAI 官方接口完全兼容，API 请求需通过 **Authorization header** 认证

| 方法  | 端点                         | 描述                               | 是否需要认证 |
|-------|------------------------------|------------------------------------|------|
| POST  | `/v1/chat/completions`       | 创建聊天对话（流式/非流式）         | ✅   |
| GET   | `/v1/models`                 | 获取全部支持模型                   | ✅   |
| GET   | `/images/{img_path}`         | 获取生成图片文件                   | ❌   |

<br>

<details>
<summary>管理与统计接口（展开查看更多）</summary>

| 方法  | 端点                    | 描述               | 认证 |
|-------|-------------------------|--------------------|------|
| GET   | /login                  | 管理员登录页面     | ❌   |
| GET   | /manage                 | 管理控制台页面     | ❌   |
| POST  | /api/login              | 管理员登录认证     | ❌   |
| POST  | /api/logout             | 管理员登出         | ✅   |
| GET   | /api/tokens             | 获取 Token 列表    | ✅   |
| POST  | /api/tokens/add         | 批量添加 Token     | ✅   |
| POST  | /api/tokens/delete      | 批量删除 Token     | ✅   |
| GET   | /api/settings           | 获取系统配置       | ✅   |
| POST  | /api/settings           | 更新系统配置       | ✅   |
| GET   | /api/cache/size         | 获取缓存大小       | ✅   |
| POST  | /api/cache/clear        | 清理所有缓存       | ✅   |
| POST  | /api/cache/clear/images | 清理图片缓存       | ✅   |
| POST  | /api/cache/clear/videos | 清理视频缓存       | ✅   |
| GET   | /api/stats              | 获取统计信息       | ✅   |
| POST  | /api/tokens/tags        | 更新 Token 标签     | ✅   |
| POST  | /api/tokens/note        | 更新 Token 备注     | ✅   |
| POST  | /api/tokens/test        | 测试 Token 可用性   | ✅   |
| GET   | /api/tokens/tags/all    | 获取所有标签列表    | ✅   |
| GET   | /api/storage/mode       | 获取存储模式信息    | ✅   |

</details>

<br>

## 可用模型一览

| 模型名称               | 计次   | 账户类型      | 图像生成/编辑 | 深度思考 | 联网搜索 | 视频生成 |
|------------------------|--------|--------------|--------------|----------|----------|----------|
| `grok-4.1`             | 1      | Basic/Super  | ✅           | ✅       | ✅       | ❌       |
| `grok-4.1-thinking`    | 1      | Basic/Super  | ✅           | ✅       | ✅       | ❌       |
| `grok-imagine-0.9`     | -      | Basic/Super  | ✅           | ❌       | ❌       | ✅       |
| `grok-4-fast`          | 1      | Basic/Super  | ✅           | ✅       | ✅       | ❌       |
| `grok-4-fast-expert`   | 4      | Basic/Super  | ✅           | ✅       | ✅       | ❌       |
| `grok-4-expert`        | 4      | Basic/Super  | ✅           | ✅       | ✅       | ❌       |
| `grok-4-heavy`         | 1      | Super        | ✅           | ✅       | ✅       | ❌       |
| `grok-3-fast`          | 1      | Basic/Super  | ✅           | ❌       | ✅       | ❌       |

<br>

## 配置参数说明

> 服务启动后，登录 `/login` 管理后台进行参数配置

| 参数名                     | 作用域  | 必填 | 说明                                    | 默认值 |
|----------------------------|---------|------|-----------------------------------------|--------|
| admin_username             | global  | 否   | 管理后台登录用户名                      | "admin"|
| admin_password             | global  | 否   | 管理后台登录密码                        | "admin"|
| log_level                  | global  | 否   | 日志级别：DEBUG/INFO/...                | "INFO" |
| image_mode                 | global  | 否   | 图片返回模式：url/base64                | "url"  |
| image_cache_max_size_mb    | global  | 否   | 图片缓存最大容量(MB)                     | 512    |
| video_cache_max_size_mb    | global  | 否   | 视频缓存最大容量(MB)                     | 1024   |
| base_url                   | global  | 否   | 服务基础URL/图片访问基准                 | ""     |
| api_key                    | grok    | 否   | API 密钥（可选加强安全）                | ""     |
| proxy_url                  | grok    | 否   | HTTP代理服务器地址                      | ""     |
| stream_chunk_timeout       | grok    | 否   | 流式分块超时时间(秒)                     | 120    |
| stream_first_response_timeout | grok | 否   | 流式首次响应超时时间(秒)                 | 30     |
| stream_total_timeout       | grok    | 否   | 流式总超时时间(秒)                       | 600    |
| cf_clearance               | grok    | 否   | Cloudflare安全令牌                      | ""     |
| x_statsig_id               | grok    | 是   | 反机器人唯一标识符                      | "ZTpUeXBlRXJyb3I6IENhbm5vdCByZWFkIHByb3BlcnRpZXMgb2YgdW5kZWZpbmVkIChyZWFkaW5nICdjaGlsZE5vZGVzJyk=" |
| filtered_tags              | grok    | 否   | 过滤响应标签（逗号分隔）                | "xaiartifact,xai:tool_usage_card,grok:render" |
| show_thinking              | grok    | 否   | 显示思考过程 true(显示)/false(隐藏)     | true   |
| temporary                  | grok    | 否   | 会话模式 true(临时)/false               | true   |

<br>

## ⚠️ 注意事项

本项目仅供学习与研究，请遵守相关使用条款！

<br>

> 本项目基于以下项目学习重构，特别感谢：[LINUX DO](https://linux.do)、[VeroFess/grok2api](https://github.com/VeroFess/grok2api)、[xLmiler/grok2api_python](https://github.com/xLmiler/grok2api_python)