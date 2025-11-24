#!/bin/bash
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[WARP] 启动脚本开始...${NC}"

# 检查是否需要安装 WARP
if ! command -v warp-cli &> /dev/null; then
    echo -e "${YELLOW}[WARP] 检测到未安装 WARP，开始安装...${NC}"
    
    # 更新系统包列表
    echo -e "${YELLOW}[WARP] 更新系统包列表...${NC}"
    apt-get update
    
    # 安装必要的依赖
    echo -e "${YELLOW}[WARP] 安装依赖包...${NC}"
    apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        ca-certificates \
        lsb-release
    
    # 添加 Cloudflare WARP 仓库
    echo -e "${YELLOW}[WARP] 添加 Cloudflare WARP 仓库...${NC}"
    curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    
    # 添加仓库源
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    
    # 更新包列表
    apt-get update
    
    # 安装 WARP
    echo -e "${YELLOW}[WARP] 安装 Cloudflare WARP...${NC}"
    apt-get install -y --no-install-recommends cloudflare-warp
    
    echo -e "${GREEN}[WARP] WARP 安装完成${NC}"
else
    echo -e "${GREEN}[WARP] WARP 已安装${NC}"
fi

# 启动 WARP 服务
echo -e "${YELLOW}[WARP] 启动 WARP 服务...${NC}"

# 启动 warp-svc 守护进程
warp-svc &
WARP_PID=$!
echo -e "${YELLOW}[WARP] WARP 守护进程 PID: $WARP_PID${NC}"

# 等待服务启动
sleep 2

# 获取 WARP 状态
echo -e "${YELLOW}[WARP] 检查 WARP 状态...${NC}"
if warp-cli status; then
    echo -e "${GREEN}[WARP] WARP 状态正常${NC}"
else
    echo -e "${YELLOW}[WARP] WARP 初始连接中...${NC}"
fi

# 连接 WARP
echo -e "${YELLOW}[WARP] 正在连接 WARP...${NC}"
if warp-cli connect 2>/dev/null || true; then
    sleep 1
    if warp-cli status | grep -q "Connected"; then
        echo -e "${GREEN}[WARP] WARP 已成功连接${NC}"
    else
        echo -e "${YELLOW}[WARP] WARP 连接中，继续启动应用...${NC}"
    fi
else
    echo -e "${YELLOW}[WARP] WARP 连接命令执行完成${NC}"
fi

echo -e "${GREEN}[WARP] WARP 初始化完成${NC}"
echo -e "${YELLOW}[App] 启动主应用程序...${NC}"

# 启动主应用
exec python -m uvicorn main:app --host 0.0.0.0 --port 8000
