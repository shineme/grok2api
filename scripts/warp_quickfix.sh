#!/bin/bash
# WARP快速修复脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WARP快速修复脚本 ===${NC}\n"

# 函数：执行命令并显示结果
execute_cmd() {
    local cmd="$1"
    local desc="$2"
    
    echo -e "${YELLOW}执行: $desc${NC}"
    echo -e "${BLUE}命令: $cmd${NC}"
    
    if eval "$cmd"; then
        echo -e "${GREEN}✓ 成功${NC}\n"
    else
        echo -e "${RED}✗ 失败${NC}\n"
        return 1
    fi
}

# 函数：检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查是否在Docker容器中
if [ ! -f /.dockerenv ]; then
    echo -e "${YELLOW}警告: 当前不在Docker容器中运行${NC}"
    echo -e "${YELLOW}某些功能可能无法正常工作${NC}\n"
fi

# 1. 清理旧的WARP进程
echo -e "${YELLOW}[1/6] 清理旧的WARP进程${NC}"
if pgrep -f "warp-svc" > /dev/null; then
    execute_cmd "pkill -f warp-svc" "终止warp-svc进程"
else
    echo -e "${GREEN}✓ 没有运行中的warp-svc进程${NC}\n"
fi

# 2. 清理旧的D-Bus进程和socket
echo -e "${YELLOW}[2/6] 清理旧的D-Bus进程和socket${NC}"
if pgrep -f "dbus-daemon" > /dev/null; then
    execute_cmd "pkill -f dbus-daemon" "终止dbus-daemon进程"
else
    echo -e "${GREEN}✓ 没有运行中的dbus-daemon进程${NC}\n"
fi

if [ -S /run/dbus/system_bus_socket ]; then
    execute_cmd "rm -f /run/dbus/system_bus_socket" "删除旧的D-Bus socket文件"
else
    echo -e "${GREEN}✓ 没有旧的D-Bus socket文件${NC}\n"
fi

# 3. 创建必要的目录
echo -e "${YELLOW}[3/6] 创建必要的目录${NC}"
execute_cmd "mkdir -p /run/dbus" "创建D-Bus运行目录"

# 4. 启动D-Bus服务
echo -e "${YELLOW}[4/6] 启动D-Bus服务${NC}"
execute_cmd "dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &" "启动D-Bus守护进程"

# 等待D-Bus启动
echo -e "${BLUE}等待D-Bus服务启动...${NC}"
sleep 2

# 验证D-Bus是否启动成功
if [ -S /run/dbus/system_bus_socket ]; then
    echo -e "${GREEN}✓ D-Bus服务启动成功${NC}\n"
else
    echo -e "${RED}✗ D-Bus服务启动失败${NC}\n"
    exit 1
fi

# 5. 启动WARP守护进程（如果已安装）
echo -e "${YELLOW}[5/6] 启动WARP守护进程${NC}"
if command_exists warp-cli; then
    execute_cmd "warp-svc &" "启动WARP守护进程"
    
    # 等待WARP服务启动
    echo -e "${BLUE}等待WARP服务启动...${NC}"
    sleep 3
    
    # 验证WARP是否启动成功
    if pgrep -f "warp-svc" > /dev/null; then
        echo -e "${GREEN}✓ WARP守护进程启动成功${NC}\n"
    else
        echo -e "${RED}✗ WARP守护进程启动失败${NC}\n"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ warp-cli未安装，跳过WARP启动${NC}\n"
fi

# 6. 连接WARP（如果已安装）
echo -e "${YELLOW}[6/6] 连接WARP${NC}"
if command_exists warp-cli; then
    echo -e "${BLUE}尝试连接WARP...${NC}"
    if warp-cli connect 2>/dev/null; then
        echo -e "${GREEN}✓ WARP连接成功${NC}\n"
        
        # 显示连接状态
        echo -e "${BLUE}WARP连接状态:${NC}"
        warp-cli status
    else
        echo -e "${YELLOW}⚠ WARP连接失败，但服务已启动${NC}"
        echo -e "${YELLOW}可以稍后手动尝试: warp-cli connect${NC}\n"
    fi
else
    echo -e "${YELLOW}⚠ warp-cli未安装，跳过WARP连接${NC}\n"
fi

# 最终状态检查
echo -e "${BLUE}=== 最终状态检查 ===${NC}\n"

echo -e "${YELLOW}D-Bus状态:${NC}"
if [ -S /run/dbus/system_bus_socket ] && pgrep -f "dbus-daemon" > /dev/null; then
    echo -e "${GREEN}✓ D-Bus服务正常运行${NC}"
else
    echo -e "${RED}✗ D-Bus服务异常${NC}"
fi

echo -e "${YELLOW}WARP状态:${NC}"
if command_exists warp-cli; then
    if pgrep -f "warp-svc" > /dev/null; then
        echo -e "${GREEN}✓ WARP守护进程运行中${NC}"
        echo -e "${BLUE}连接状态:${NC}"
        warp-cli status 2>/dev/null || echo -e "${RED}无法获取状态${NC}"
    else
        echo -e "${RED}✗ WARP守护进程未运行${NC}"
    fi
else
    echo -e "${YELLOW}⚠ WARP未安装${NC}"
fi

echo -e "\n${GREEN}快速修复完成！${NC}"
echo -e "${BLUE}如果问题仍然存在，请运行详细的故障排除脚本:${NC}"
echo -e "${BLUE}./scripts/warp_troubleshoot.sh${NC}"