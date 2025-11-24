#!/bin/bash
# WARP连接故障排除脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WARP连接故障排除脚本 ===${NC}\n"

# 检查运行环境
echo -e "${YELLOW}[1] 检查运行环境${NC}"
if [ -f /.dockerenv ]; then
    echo -e "${GREEN}✓ 运行在Docker容器中${NC}"
    IN_DOCKER=true
else
    echo -e "${YELLOW}⚠ 未运行在Docker容器中（WARP功能有限）${NC}"
    IN_DOCKER=false
fi

# 检查权限
echo -e "\n${YELLOW}[2] 检查系统权限${NC}"
if [ -r /dev/net/tun ] 2>/dev/null; then
    echo -e "${GREEN}✓ TUN设备可访问${NC}"
else
    echo -e "${RED}✗ TUN设备不可访问${NC}"
fi

# 检查WARP安装
echo -e "\n${YELLOW}[3] 检查WARP安装${NC}"
if command -v warp-cli &> /dev/null; then
    echo -e "${GREEN}✓ warp-cli已安装${NC}"
    WARP_INSTALLED=true
    
    # 检查WARP版本
    WARP_VERSION=$(warp-cli --version 2>/dev/null || echo "未知版本")
    echo -e "${BLUE}  版本: $WARP_VERSION${NC}"
else
    echo -e "${RED}✗ warp-cli未安装${NC}"
    WARP_INSTALLED=false
fi

# 检查D-Bus服务
echo -e "\n${YELLOW}[4] 检查D-Bus服务${NC}"
if [ -S /run/dbus/system_bus_socket ]; then
    echo -e "${GREEN}✓ D-Bus socket存在${NC}"
    DBUS_SOCKET=true
else
    echo -e "${RED}✗ D-Bus socket不存在${NC}"
    DBUS_SOCKET=false
fi

if pgrep -f "dbus-daemon" > /dev/null; then
    echo -e "${GREEN}✓ D-Bus守护进程运行中${NC}"
    DBUS_RUNNING=true
else
    echo -e "${RED}✗ D-Bus守护进程未运行${NC}"
    DBUS_RUNNING=false
fi

# 检查WARP守护进程
echo -e "\n${YELLOW}[5] 检查WARP守护进程${NC}"
if pgrep -f "warp-svc" > /dev/null; then
    echo -e "${GREEN}✓ warp-svc守护进程运行中${NC}"
    WARP_SVC_RUNNING=true
else
    echo -e "${RED}✗ warp-svc守护进程未运行${NC}"
    WARP_SVC_RUNNING=false
fi

# 获取WARP状态
echo -e "\n${YELLOW}[6] WARP状态检查${NC}"
if [ "$WARP_INSTALLED" = true ]; then
    echo -e "${BLUE}执行: warp-cli status${NC}"
    if WARP_STATUS=$(warp-cli status 2>&1); then
        echo -e "${GREEN}$WARP_STATUS${NC}"
        
        if echo "$WARP_STATUS" | grep -q "Connected"; then
            WARP_CONNECTED=true
        elif echo "$WARP_STATUS" | grep -q "Connecting"; then
            WARP_CONNECTING=true
        else
            WARP_CONNECTED=false
        fi
    else
        echo -e "${RED}获取WARP状态失败${NC}"
        echo -e "${RED}$WARP_STATUS${NC}"
        WARP_CONNECTED=false
    fi
else
    echo -e "${YELLOW}跳过WARP状态检查（未安装）${NC}"
fi

# 网络连通性测试
echo -e "\n${YELLOW}[7] 网络连通性测试${NC}"
echo -e "${BLUE}测试连接到Cloudflare DNS...${NC}"
if timeout 5 curl -s https://1.1.1.1 > /dev/null; then
    echo -e "${GREEN}✓ 网络连通正常${NC}"
    NETWORK_OK=true
else
    echo -e "${RED}✗ 网络连通异常${NC}"
    NETWORK_OK=false
fi

# 故障诊断和建议
echo -e "\n${BLUE}=== 故障诊断和建议 ===${NC}"

if [ "$WARP_INSTALLED" = false ]; then
    echo -e "\n${YELLOW}问题: WARP未安装${NC}"
    echo -e "${GREEN}解决方案:${NC}"
    echo "1. 在Docker容器中运行应用（推荐）"
    echo "2. 手动安装WARP:"
    echo "   curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
    echo "   echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main' | tee /etc/apt/sources.list.d/cloudflare-client.list"
    echo "   apt-get update && apt-get install -y cloudflare-warp"
elif [ "$WARP_SVC_RUNNING" = false ]; then
    echo -e "\n${YELLOW}问题: WARP守护进程未运行${NC}"
    echo -e "${GREEN}解决方案:${NC}"
    echo "1. 启动D-Bus服务（如果未运行）:"
    echo "   mkdir -p /run/dbus"
    echo "   dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &"
    echo "2. 启动WARP守护进程:"
    echo "   warp-svc &"
    echo "3. 等待几秒钟后检查状态"
elif [ "$DBUS_RUNNING" = false ] || [ "$DBUS_SOCKET" = false ]; then
    echo -e "\n${YELLOW}问题: D-Bus服务异常${NC}"
    echo -e "${GREEN}解决方案:${NC}"
    echo "1. 创建D-Bus运行目录:"
    echo "   mkdir -p /run/dbus"
    echo "2. 启动D-Bus守护进程:"
    echo "   dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &"
    echo "3. 重启WARP服务"
elif [ "$WARP_CONNECTED" = false ] && [ "$WARP_INSTALLED" = true ]; then
    echo -e "\n${YELLOW}问题: WARP未连接${NC}"
    echo -e "${GREEN}解决方案:${NC}"
    echo "1. 尝试连接WARP:"
    echo "   warp-cli connect"
    echo "2. 如果连接失败，尝试重启服务:"
    echo "   pkill warp-svc"
    echo "   warp-svc &"
    echo "   sleep 2"
    echo "   warp-cli connect"
fi

if [ "$IN_DOCKER" = false ]; then
    echo -e "\n${YELLOW}注意: 当前不在Docker容器中运行${NC}"
    echo -e "${GREEN}建议:${NC}"
    echo "1. 使用Docker运行以获得完整的WARP支持"
    echo "2. 确保Docker容器有适当的权限:"
    echo "   docker run --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \\"
    echo "     --sysctl net.ipv6.conf.all.disable_ipv6=0 \\"
    echo "     --sysctl net.ipv4.ip_forward=1 ..."
fi

# 自动修复选项
echo -e "\n${BLUE}=== 自动修复选项 ===${NC}"
if [ "$WARP_INSTALLED" = true ] && [ "$DBUS_RUNNING" = false ]; then
    echo -e "${YELLOW}是否尝试自动启动D-Bus服务? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}启动D-Bus服务...${NC}"
        mkdir -p /run/dbus
        dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &
        sleep 2
        echo -e "${GREEN}D-Bus服务已启动${NC}"
    fi
fi

if [ "$WARP_INSTALLED" = true ] && [ "$WARP_SVC_RUNNING" = false ]; then
    echo -e "${YELLOW}是否尝试自动启动WARP守护进程? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}启动WARP守护进程...${NC}"
        warp-svc &
        sleep 3
        echo -e "${GREEN}WARP守护进程已启动${NC}"
        
        echo -e "${YELLOW}是否尝试连接WARP? (y/N)${NC}"
        read -r connect_response
        if [[ "$connect_response" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}连接WARP...${NC}"
            if warp-cli connect; then
                echo -e "${GREEN}WARP连接成功${NC}"
                warp-cli status
            else
                echo -e "${RED}WARP连接失败${NC}"
            fi
        fi
    fi
fi

echo -e "\n${GREEN}故障排除完成！${NC}"
echo -e "${BLUE}如需进一步帮助，请查看日志: journalctl -u warp-svc -f${NC}"