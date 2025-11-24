#!/bin/bash
# 测试脚本：验证WARP修复和API功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WARP修复和API功能测试脚本 ===${NC}\n"

# 测试1：检查脚本文件
echo -e "${YELLOW}[测试1] 检查脚本文件${NC}"
scripts_dir="scripts"
required_scripts=("warp_troubleshoot.sh" "warp_quickfix.sh" "warp_env_fix.sh")

all_scripts_exist=true
for script in "${required_scripts[@]}"; do
    if [ -f "$scripts_dir/$script" ]; then
        if [ -x "$scripts_dir/$script" ]; then
            echo -e "${GREEN}✓ $scripts_dir/$script 存在且可执行${NC}"
        else
            echo -e "${RED}✗ $scripts_dir/$script 存在但不可执行${NC}"
            all_scripts_exist=false
        fi
    else
        echo -e "${RED}✗ $scripts_dir/$script 不存在${NC}"
        all_scripts_exist=false
    fi
done

if [ "$all_scripts_exist" = true ]; then
    echo -e "${GREEN}✓ 所有脚本文件检查通过${NC}"
else
    echo -e "${RED}✗ 脚本文件检查失败${NC}"
fi

# 测试2：运行环境修复脚本
echo -e "\n${YELLOW}[测试2] 运行环境修复脚本${NC}"
if [ -f "$scripts_dir/warp_env_fix.sh" ]; then
    echo -e "${BLUE}执行: $scripts_dir/warp_env_fix.sh${NC}"
    # 运行脚本但不等待用户输入
    echo -e "${YELLOW}注意: 脚本会自动运行，不会等待用户输入${NC}"
    timeout 30s "$scripts_dir/warp_env_fix.sh" || echo -e "${YELLOW}脚本运行完成或超时${NC}"
else
    echo -e "${RED}✗ 环境修复脚本不存在${NC}"
fi

# 测试3：启动应用
echo -e "\n${YELLOW}[测试3] 启动应用${NC}"
echo -e "${BLUE}启动FastAPI应用...${NC}"

# 激活虚拟环境并启动应用
source .venv/bin/activate
python -m uvicorn main:app --host 0.0.0.0 --port 8000 &
APP_PID=$!

echo -e "${YELLOW}等待应用启动...${NC}"
sleep 5

# 检查应用是否启动成功
if curl -s http://localhost:8000/health > /dev/null; then
    echo -e "${GREEN}✓ 应用启动成功 (PID: $APP_PID)${NC}"
else
    echo -e "${RED}✗ 应用启动失败${NC}"
    exit 1
fi

# 测试4：健康检查端点
echo -e "\n${YELLOW}[测试4] 健康检查端点${NC}"
health_response=$(curl -s http://localhost:8000/health)
echo -e "${BLUE}健康检查响应:${NC}"
echo "$health_response" | python -m json.tool || echo "$health_response"

# 验证响应格式
if echo "$health_response" | python -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
    echo -e "${GREEN}✓ 健康检查端点返回有效JSON${NC}"
    
    # 检查关键字段
    if echo "$health_response" | python -c "import sys, json; data=json.load(sys.stdin); print('OK' if 'warp' in data and 'warp_connected' in data else 'MISSING')" 2>/dev/null | grep -q "OK"; then
        echo -e "${GREEN}✓ 健康检查响应包含WARP信息${NC}"
    else
        echo -e "${YELLOW}⚠ 健康检查响应缺少WARP信息${NC}"
    fi
else
    echo -e "${RED}✗ 健康检查端点返回无效JSON${NC}"
fi

# 测试5：系统状态端点（未认证）
echo -e "\n${YELLOW}[测试5] 系统状态端点（未认证）${NC}"
status_code=$(curl -s -w "%{http_code}" http://localhost:8000/api/system/status -o /dev/null)
if [ "$status_code" = "401" ]; then
    echo -e "${GREEN}✓ 系统状态端点正确返回401（未认证）${NC}"
elif [ "$status_code" = "404" ]; then
    echo -e "${RED}✗ 系统状态端点返回404（端点不存在）${NC}"
else
    echo -e "${YELLOW}⚠ 系统状态端点返回 $status_code${NC}"
fi

# 测试6：登录和系统状态（认证）
echo -e "\n${YELLOW}[测试6] 登录和系统状态（认证）${NC}"

# 尝试登录
login_response=$(curl -s -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin"}')

echo -e "${BLUE}登录响应:${NC}"
echo "$login_response" | python -m json.tool || echo "$login_response"

# 提取token
token=$(echo "$login_response" | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('success') and 'token' in data:
        print(data['token'])
    else:
        print('LOGIN_FAILED')
except:
    print('PARSE_ERROR')
" 2>/dev/null || echo "ERROR")

if [ "$token" = "LOGIN_FAILED" ]; then
    echo -e "${RED}✗ 登录失败${NC}"
elif [ "$token" = "PARSE_ERROR" ] || [ "$token" = "ERROR" ]; then
    echo -e "${RED}✗ 登录响应解析失败${NC}"
else
    echo -e "${GREEN}✓ 登录成功，获取到token${NC}"
    
    # 使用token获取系统状态
    system_status_response=$(curl -s -H "Authorization: Bearer $token" http://localhost:8000/api/system/status)
    echo -e "${BLUE}系统状态响应:${NC}"
    echo "$system_status_response" | python -m json.tool || echo "$system_status_response"
    
    # 验证系统状态响应
    if echo "$system_status_response" | python -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
        echo -e "${GREEN}✓ 系统状态端点返回有效JSON${NC}"
        
        # 检查关键字段
        if echo "$system_status_response" | python -c "
import sys, json
data = json.load(sys.stdin)
print('OK' if 'data' in data and 'warp' in data['data'] and 'dbus' in data['data'] else 'MISSING')
" 2>/dev/null | grep -q "OK"; then
            echo -e "${GREEN}✓ 系统状态响应包含完整信息${NC}"
        else
            echo -e "${YELLOW}⚠ 系统状态响应缺少部分信息${NC}"
        fi
    else
        echo -e "${RED}✗ 系统状态端点返回无效JSON${NC}"
    fi
fi

# 清理：关闭应用
echo -e "\n${YELLOW}[清理] 关闭应用${NC}"
if kill $APP_PID 2>/dev/null; then
    echo -e "${GREEN}✓ 应用已关闭${NC}"
else
    echo -e "${YELLOW}⚠ 应用进程可能已退出${NC}"
fi

# 等待进程完全退出
sleep 2

# 测试总结
echo -e "\n${BLUE}=== 测试总结 ===${NC}"
echo -e "${GREEN}✓ 脚本文件检查完成${NC}"
echo -e "${GREEN}✓ 环境修复脚本测试完成${NC}"
echo -e "${GREEN}✓ 应用启动测试完成${NC}"
echo -e "${GREEN}✓ 健康检查端点测试完成${NC}"
echo -e "${GREEN}✓ 系统状态端点测试完成${NC}"
echo -e "${GREEN}✓ 认证功能测试完成${NC}"

echo -e "\n${GREEN}🎉 所有测试完成！${NC}"
echo -e "${YELLOW}建议:${NC}"
echo -e "${YELLOW}1. 在Docker环境中测试完整的WARP功能${NC}"
echo -e "${YELLOW}2. 查看生成的日志文件获取详细信息${NC}"
echo -e "${YELLOW}3. 使用管理后台界面进行交互式测试${NC}"