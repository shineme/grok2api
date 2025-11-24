#!/bin/bash
# Docker环境下的WARP状态检查测试

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Docker环境WARP状态检查测试 ===${NC}"

# 构建镜像
echo -e "${YELLOW}[1/4] 构建Docker镜像...${NC}"
docker build -t grok2api-warp-test .

# 运行容器
echo -e "${YELLOW}[2/4] 启动容器...${NC}"
CONTAINER_ID=$(docker run -d --rm \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_ADMIN \
    --sysctl net.ipv6.conf.all.disable_ipv6=0 \
    --sysctl net.ipv4.ip_forward=1 \
    -p 8000:8000 \
    grok2api-warp-test)

echo -e "${GREEN}容器ID: $CONTAINER_ID${NC}"

# 等待容器启动
echo -e "${YELLOW}[3/4] 等待服务启动...${NC}"
sleep 10

# 检查容器内WARP状态
echo -e "${YELLOW}[4/4] 检查WARP状态...${NC}"

echo -e "\n${GREEN}=== WARP安装检查 ===${NC}"
docker exec $CONTAINER_ID which warp-cli || echo -e "${RED}warp-cli未找到${NC}"

echo -e "\n${GREEN}=== WARP服务状态 ===${NC}"
docker exec $CONTAINER_ID warp-cli status || echo -e "${RED}无法获取WARP状态${NC}"

echo -e "\n${GREEN}=== D-Bus服务状态 ===${NC}"
docker exec $CONTAINER_ID ls -la /run/dbus/system_bus_socket || echo -e "${RED}D-Bus socket不存在${NC}"

echo -e "\n${GREEN}=== 健康检查API ===${NC}"
curl -s http://localhost:8000/health | python3 -m json.tool || echo -e "${RED}健康检查失败${NC}"

echo -e "\n${GREEN}=== 系统状态API（需要先登录） ===${NC}"
echo "要测试系统状态API，请："
echo "1. 访问 http://localhost:8000/login"
echo "2. 使用 admin/admin 登录"
echo "3. 调用 /api/system/status API"

# 清理
echo -e "\n${YELLOW}清理容器...${NC}"
docker stop $CONTAINER_ID

echo -e "${GREEN}测试完成！${NC}"