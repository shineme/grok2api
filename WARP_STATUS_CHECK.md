# WARP连接状态检查功能

本文档说明了如何检查Docker环境内的WARP连接状态。

## 功能概述

我们为Grok2API项目添加了完整的WARP连接状态检查功能，包括：

1. **基础健康检查端点** - 简单的WARP连接状态
2. **详细系统状态API** - 完整的系统状态信息
3. **容器内直接检查** - 命令行工具

## 使用方法

### 1. 健康检查端点

**端点**: `GET /health`

**示例**:
```bash
curl http://localhost:8000/health
```

**响应示例**:
```json
{
  "status": "healthy",
  "service": "Grok2API", 
  "version": "1.0.3",
  "warp_connected": true
}
```

### 2. 详细系统状态API

**端点**: `GET /api/system/status`（需要管理员认证）

**步骤**:
1. 登录管理后台获取token:
```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin"}'
```

2. 使用token获取系统状态:
```bash
curl -H "Authorization: Bearer <token>" \
  http://localhost:8000/api/system/status
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "overall_status": "正常",
    "healthy": true,
    "storage_mode": "FILE",
    "warp": {
      "installed": true,
      "connected": true,
      "status": "已连接",
      "details": "Status update: Connected",
      "error": null
    },
    "dbus": {
      "running": true,
      "status": "运行中",
      "socket_exists": true
    },
    "network": {
      "connected": true,
      "status": "连通",
      "error": null
    },
    "timestamp": "2024-11-24T12:52:05.155000"
  }
}
```

### 3. 容器内直接检查

```bash
# 进入容器
docker exec -it <container_id> bash

# 检查WARP状态
warp-cli status

# 检查D-Bus服务
ls -la /run/dbus/system_bus_socket

# 检查warp-svc进程
ps aux | grep warp-svc
```

## 状态说明

### WARP状态
- **已连接**: WARP正常工作，流量通过WARP代理
- **连接中**: WARP正在尝试连接
- **未连接**: WARP已安装但未连接
- **未安装**: WARP客户端未安装
- **错误**: 检查过程中出现错误

### D-Bus状态
- **运行中**: D-Bus服务正常运行
- **未运行**: D-Bus服务未启动

### 网络连通性
- **连通**: 可以访问外部网络（测试1.1.1.1）
- **不通**: 无法访问外部网络

## 故障排除

### WARP未连接
1. 检查容器是否有足够权限：
   ```bash
   docker run --cap-add=NET_ADMIN --cap-add=SYS_ADMIN ...
   ```

2. 检查系统参数：
   ```bash
   --sysctl net.ipv6.conf.all.disable_ipv6=0
   --sysctl net.ipv4.ip_forward=1
   ```

3. 手动连接：
   ```bash
   docker exec <container_id> warp-cli connect
   ```

### D-Bus服务异常
1. 重启D-Bus：
   ```bash
   docker exec <container_id> dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &
   ```

### 网络不通
1. 检查容器网络配置
2. 验证DNS设置
3. 检查防火墙规则

## 测试脚本

项目提供了测试脚本来验证功能：

1. **本地测试**:
   ```bash
   python test_warp_status.py
   ```

2. **API测试**:
   ```bash
   python test_warp_api.py
   ```

3. **Docker测试**:
   ```bash
   ./test_warp_docker.sh
   ```

## 集成说明

这些功能已集成到现有的管理后台中，可以通过Web界面查看系统状态，也可以通过API进行程序化检查。所有检查都是非阻塞的，不会影响正常的API服务。