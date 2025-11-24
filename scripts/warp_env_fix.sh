#!/bin/bash
# WARP环境检查和修复脚本
# 专门用于解决"Registration Missing due to: Daemon Startup"错误

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WARP环境检查和修复脚本 ===${NC}"
echo -e "${BLUE}解决'Registration Missing due to: Daemon Startup'错误${NC}\n"

# 检查运行环境
echo -e "${YELLOW}[1] 检查运行环境${NC}"
if [ -f /.dockerenv ]; then
    echo -e "${GREEN}✓ 运行在Docker容器中${NC}"
    IN_DOCKER=true
else
    echo -e "${YELLOW}⚠ 未运行在Docker容器中${NC}"
    echo -e "${YELLOW}  注意: WARP功能在非Docker环境中可能受限${NC}"
    IN_DOCKER=false
fi

# 检查权限
echo -e "\n${YELLOW}[2] 检查系统权限${NC}"
if [ -r /dev/net/tun ] 2>/dev/null; then
    echo -e "${GREEN}✓ TUN设备可访问${NC}"
    TUN_OK=true
else
    echo -e "${RED}✗ TUN设备不可访问${NC}"
    echo -e "${YELLOW}  建议: 使用以下权限运行Docker容器:${NC}"
    echo -e "${YELLOW}    --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \\${NC}"
    echo -e "${YELLOW}    --sysctl net.ipv6.conf.all.disable_ipv6=0 \\${NC}"
    echo -e "${YELLOW}    --sysctl net.ipv4.ip_forward=1${NC}"
    TUN_OK=false
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
    echo -e "${YELLOW}  解决方案:${NC}"
    echo -e "${YELLOW}  1. 在Docker容器中运行应用（推荐）${NC}"
    echo -e "${YELLOW}  2. 手动安装WARP:${NC}"
    echo -e "${YELLOW}     curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg${NC}"
    echo -e "${YELLOW}     echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ \$(lsb_release -cs) main' | tee /etc/apt/sources.list.d/cloudflare-client.list${NC}"
    echo -e "${YELLOW}     apt-get update && apt-get install -y cloudflare-warp${NC}"
    WARP_INSTALLED=false
fi

# 修复D-Bus服务
echo -e "\n${YELLOW}[4] 修复D-Bus服务${NC}"
DBUS_FIXED=false

# 清理旧的D-Bus进程和socket
echo -e "${BLUE}  清理旧的D-Bus进程和socket...${NC}"
pkill -f dbus-daemon 2>/dev/null || true
rm -f /run/dbus/system_bus_socket 2>/dev/null || true

# 创建D-Bus运行目录
mkdir -p /run/dbus 2>/dev/null || true

# 启动D-Bus守护进程
if command -v dbus-daemon &> /dev/null; then
    echo -e "${BLUE}  启动D-Bus守护进程...${NC}"
    dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &
    DBUS_PID=$!
    sleep 2
    
    # 检查D-Bus是否成功启动
    if [ -S /run/dbus/system_bus_socket ]; then
        echo -e "${GREEN}✓ D-Bus服务启动成功 (PID: $DBUS_PID)${NC}"
        DBUS_FIXED=true
    else
        echo -e "${RED}✗ D-Bus服务启动失败${NC}"
    fi
else
    echo -e "${RED}✗ dbus-daemon未安装${NC}"
    echo -e "${YELLOW}  安装命令: apt-get install -y dbus${NC}"
fi

# 修复WARP守护进程
echo -e "\n${YELLOW}[5] 修复WARP守护进程${NC}"
WARP_FIXED=false

if [ "$WARP_INSTALLED" = true ]; then
    # 清理旧的WARP进程
    echo -e "${BLUE}  清理旧的WARP进程...${NC}"
    pkill -f warp-svc 2>/dev/null || true
    sleep 1
    
    # 启动WARP守护进程
    echo -e "${BLUE}  启动WARP守护进程...${NC}"
    warp-svc &
    WARP_PID=$!
    sleep 3
    
    # 检查WARP守护进程是否运行
    if pgrep -f "warp-svc" > /dev/null; then
        echo -e "${GREEN}✓ WARP守护进程启动成功 (PID: $WARP_PID)${NC}"
        WARP_FIXED=true
    else
        echo -e "${RED}✗ WARP守护进程启动失败${NC}"
    fi
else
    echo -e "${YELLOW}  跳过WARP守护进程修复（未安装）${NC}"
fi

# 尝试连接WARP
echo -e "\n${YELLOW}[6] 尝试连接WARP${NC}"
if [ "$WARP_INSTALLED" = true ] && [ "$WARP_FIXED" = true ]; then
    echo -e "${BLUE}  尝试连接WARP...${NC}"
    
    # 尝试连接
    if warp-cli connect 2>/dev/null; then
        sleep 2
        
        # 检查连接状态
        if warp-cli status 2>/dev/null | grep -q "Connected"; then
            echo -e "${GREEN}✓ WARP连接成功${NC}"
            WARP_CONNECTED=true
        elif warp-cli status 2>/dev/null | grep -q "Connecting"; then
            echo -e "${YELLOW}⚠ WARP连接中...${NC}"
            WARP_CONNECTED=false
        else
            echo -e "${RED}✗ WARP连接失败${NC}"
            WARP_CONNECTED=false
        fi
    else
        echo -e "${RED}✗ WARP连接命令失败${NC}"
        WARP_CONNECTED=false
    fi
else
    echo -e "${YELLOW}  跳过WARP连接（WARP未就绪）${NC}"
    WARP_CONNECTED=false
fi

# 最终状态检查
echo -e "\n${BLUE}=== 最终状态检查 ===${NC}"

if [ "$WARP_INSTALLED" = true ]; then
    echo -e "${BLUE}WARP状态:${NC}"
    warp-cli status 2>/dev/null || echo -e "${RED}  状态获取失败${NC}"
else
    echo -e "${YELLOW}WARP未安装${NC}"
fi

echo -e "\n${BLUE}进程状态:${NC}"
if pgrep -f "dbus-daemon" > /dev/null; then
    echo -e "${GREEN}✓ D-Bus守护进程运行中${NC}"
else
    echo -e "${RED}✗ D-Bus守护进程未运行${NC}"
fi

if pgrep -f "warp-svc" > /dev/null; then
    echo -e "${GREEN}✓ WARP守护进程运行中${NC}"
else
    echo -e "${RED}✗ WARP守护进程未运行${NC}"
fi

# 总结和建议
echo -e "\n${BLUE}=== 总结和建议 ===${NC}"

if [ "$WARP_CONNECTED" = true ]; then
    echo -e "${GREEN}🎉 WARP修复成功！${NC}"
    echo -e "${GREEN}   现在可以使用WARP功能了${NC}"
elif [ "$WARP_INSTALLED" = true ] && [ "$WARP_FIXED" = true ] && [ "$DBUS_FIXED" = true ]; then
    echo -e "${YELLOW}⚠ WARP服务已启动但连接失败${NC}"
    echo -e "${YELLOW}   建议:${NC}"
    echo -e "${YELLOW}   1. 等待几秒钟后再次检查状态${NC}"
    echo -e "${YELLOW}   2. 检查网络连接${NC}"
    echo -e "${YELLOW}   3. 重启容器重试${NC}"
elif [ "$WARP_INSTALLED" = false ]; then
    echo -e "${RED}❌ WARP未安装${NC}"
    echo -e "${YELLOW}   建议:${NC}"
    echo -e "${YELLOW}   1. 使用Docker容器运行应用${NC}"
    echo -e "${YELLOW}   2. 或手动安装WARP客户端${NC}"
else
    echo -e "${RED}❌ WARP服务启动失败${NC}"
    echo -e "${YELLOW}   建议:${NC}"
    echo -e "${YELLOW}   1. 检查容器权限设置${NC}"
    echo -e "${YELLOW}   2. 确保系统支持TUN/TAP设备${NC}"
    echo -e "${YELLOW}   3. 查看系统日志获取详细错误${NC}"
fi

echo -e "\n${BLUE}=== API测试建议 ===${NC}"
echo -e "${YELLOW}1. 健康检查:${NC}"
echo -e "${YELLOW}   curl http://localhost:8000/health${NC}"
echo -e "${YELLOW}2. 系统状态（需要登录）:${NC}"
echo -e "${YELLOW}   curl -X POST http://localhost:8000/api/login -H 'Content-Type: application/json' -d '{\"username\": \"admin\", \"password\": \"admin\"'}${NC}"
echo -e "${YELLOW}   curl -H \"Authorization: Bearer <token>\" http://localhost:8000/api/system/status${NC}"

echo -e "\n${GREEN}修复脚本执行完成！${NC}"