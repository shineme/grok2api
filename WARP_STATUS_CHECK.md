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

### 自动故障排除

我们提供了两个自动化脚本来帮助解决WARP连接问题：

#### 1. 详细故障排除脚本

```bash
# 在容器内或本地运行
./scripts/warp_troubleshoot.sh
```

该脚本会全面检查：
- 运行环境（Docker/本地）
- 系统权限（TUN设备访问）
- WARP安装和版本
- D-Bus服务状态
- WARP守护进程状态
- 网络连通性

并提供针对性的修复建议和自动修复选项。

#### 2. 快速修复脚本

```bash
# 快速修复常见WARP连接问题
./scripts/warp_quickfix.sh
```

该脚本会自动执行以下修复步骤：
1. 清理旧的WARP和D-Bus进程
2. 删除旧的socket文件
3. 重新创建必要目录
4. 启动D-Bus服务
5. 启动WARP守护进程
6. 尝试连接WARP

适用于大多数常见的WARP连接问题。

### 常见问题解决

#### WARP未连接
1. **检查容器权限**：
   ```bash
   docker run --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \
     --sysctl net.ipv6.conf.all.disable_ipv6=0 \
     --sysctl net.ipv4.ip_forward=1 \
     your-image
   ```

2. **启动D-Bus服务**：
   ```bash
   mkdir -p /run/dbus
   dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &
   ```

3. **启动WARP守护进程**：
   ```bash
   warp-svc &
   sleep 2
   ```

4. **连接WARP**：
   ```bash
   warp-cli connect
   ```

#### "Registration Missing due to: Daemon Startup" 错误

这个错误通常表示WARP守护进程启动失败：

1. **重启守护进程**：
   ```bash
   pkill warp-svc
   warp-svc &
   sleep 3
   warp-cli connect
   ```

2. **检查D-Bus服务**：
   ```bash
   ls -la /run/dbus/system_bus_socket
   ```

3. **在Docker容器中运行**：
   确保使用正确的权限和系统参数。

#### D-Bus服务异常

1. **手动启动D-Bus**：
   ```bash
   mkdir -p /run/dbus
   dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &
   ```

2. **检查socket权限**：
   ```bash
   ls -la /run/dbus/
   ```

3. **清理旧的socket文件**：
   ```bash
   rm -f /run/dbus/system_bus_socket
   # 重新启动D-Bus服务
   ```

#### 网络连通性问题

1. **测试基础连接**：
   ```bash
   curl -I https://1.1.1.1
   ```

2. **检查DNS解析**：
   ```bash
   nslookup 1.1.1.1
   ```

3. **查看容器网络**：
   ```bash
   ip addr show
   route -n
   ```

### 本地开发环境

如果在本地开发环境中，WARP功能可能受限：
- 建议使用Docker容器进行开发和测试
- 或者手动安装WARP客户端（需要root权限）

### 日志查看

```bash
# 查看WARP服务日志
journalctl -u warp-svc -f

# 查看系统日志
dmesg | grep -i warp

# 查看D-Bus日志
journalctl -u dbus -f
```

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