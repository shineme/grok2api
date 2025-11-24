# WARP "Registration Missing due to: Daemon Startup" 错误解决方案

## 问题描述

当运行 `warp-cli status` 时出现以下错误：
```
Status update: Unable
Reason: Registration Missing due to: Daemon Startup
```

## 根本原因

这个错误通常表示WARP守护进程（warp-svc）没有正常启动或无法与D-Bus服务通信。

## 解决方案

### 方案1：使用快速修复脚本（推荐）

```bash
# 在容器内运行
./scripts/warp_quickfix.sh
```

这个脚本会自动：
1. 清理旧的进程和socket文件
2. 重新启动D-Bus服务
3. 启动WARP守护进程
4. 尝试连接WARP

### 方案2：手动修复步骤

#### 步骤1：清理旧进程
```bash
# 终止可能存在的WARP和D-Bus进程
pkill -f warp-svc
pkill -f dbus-daemon

# 删除旧的socket文件
rm -f /run/dbus/system_bus_socket
```

#### 步骤2：启动D-Bus服务
```bash
# 创建D-Bus运行目录
mkdir -p /run/dbus

# 启动D-Bus守护进程
dbus-daemon --system --nofork --nopidfile --address=unix:path=/run/dbus/system_bus_socket &

# 等待服务启动
sleep 2
```

#### 步骤3：验证D-Bus服务
```bash
# 检查socket文件是否存在
ls -la /run/dbus/system_bus_socket

# 检查进程是否运行
ps aux | grep dbus-daemon
```

#### 步骤4：启动WARP守护进程
```bash
# 启动warp-svc守护进程
warp-svc &

# 等待服务启动
sleep 3
```

#### 步骤5：连接WARP
```bash
# 尝试连接
warp-cli connect

# 检查状态
warp-cli status
```

### 方案3：使用详细故障排除

```bash
# 运行详细的故障排除脚本
./scripts/warp_troubleshoot.sh
```

该脚本会：
- 检查所有相关服务的状态
- 提供详细的诊断信息
- 给出针对性的修复建议
- 提供自动修复选项

## 预防措施

### 1. 确保正确的Docker权限

在运行Docker容器时，确保包含必要的权限：

```bash
docker run --cap-add=NET_ADMIN \
           --cap-add=SYS_ADMIN \
           --sysctl net.ipv6.conf.all.disable_ipv6=0 \
           --sysctl net.ipv4.ip_forward=1 \
           your-image
```

### 2. 使用官方的启动脚本

项目提供的 `docker-entrypoint.sh` 已经包含了正确的启动顺序：
1. 启动D-Bus服务
2. 启动WARP守护进程
3. 连接WARP
4. 启动应用程序

### 3. 检查系统兼容性

确保系统满足以下要求：
- 支持TUN/TAP设备
- 具有必要的系统权限
- 内核版本兼容

## 验证修复

修复后，可以通过以下方式验证：

### 1. 命令行检查
```bash
# 检查WARP状态
warp-cli status

# 预期输出应包含 "Connected"
```

### 2. API检查
```bash
# 健康检查端点
curl http://localhost:8000/health

# 预期输出应包含 "warp_connected": true
```

### 3. 系统状态API
```bash
# 需要先登录获取token
curl -H "Authorization: Bearer <token>" \
     http://localhost:8000/api/system/status

# 检查warp.connected字段
```

## 常见变体错误

### "Registration Missing" (无Daemon Startup)
通常表示WARP守护进程完全未运行。

### "Unable to connect to WARP service"
表示warp-cli无法与warp-svc通信。

### "Permission denied"
通常是权限问题，需要NET_ADMIN和SYS_ADMIN权限。

## 获取帮助

如果问题仍然存在：

1. **查看日志**：
   ```bash
   journalctl -u warp-svc -f
   ```

2. **运行诊断脚本**：
   ```bash
   ./scripts/warp_troubleshoot.sh
   ```

3. **检查系统状态**：
   ```bash
   # 通过API检查
   curl http://localhost:8000/api/system/status
   ```

4. **重启容器**：
   有时简单的容器重启可以解决临时性问题。

## 总结

"Registration Missing due to: Daemon Startup" 错误通常是WARP服务启动顺序或权限问题。使用提供的快速修复脚本可以自动解决大多数情况，而手动修复步骤可以帮助理解问题的根本原因。