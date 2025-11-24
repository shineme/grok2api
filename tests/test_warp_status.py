#!/usr/bin/env python3
"""
测试WARP状态检查功能
"""

import asyncio
import sys
import os

# 添加项目根目录到Python路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.api.admin.manage import _check_warp_status, _check_dbus_status, _check_network_connectivity


async def test_warp_status():
    """测试WARP状态检查"""
    print("=== 测试WARP状态检查 ===")
    
    try:
        warp_status = await _check_warp_status()
        print(f"WARP状态: {warp_status}")
        
        if warp_status.get("installed"):
            print(f"✓ WARP已安装")
            if warp_status.get("connected"):
                print(f"✓ WARP已连接")
            else:
                print(f"✗ WARP未连接: {warp_status.get('status')}")
        else:
            print(f"✗ WARP未安装")
            
        if warp_status.get("error"):
            print(f"错误信息: {warp_status.get('error')}")
            
    except Exception as e:
        print(f"测试异常: {e}")


async def test_dbus_status():
    """测试D-Bus状态检查"""
    print("\n=== 测试D-Bus状态检查 ===")
    
    try:
        dbus_status = await _check_dbus_status()
        print(f"D-Bus状态: {dbus_status}")
        
        if dbus_status.get("running"):
            print(f"✓ D-Bus服务运行中")
        else:
            print(f"✗ D-Bus服务未运行: {dbus_status.get('status')}")
            
        if dbus_status.get("error"):
            print(f"错误信息: {dbus_status.get('error')}")
            
    except Exception as e:
        print(f"测试异常: {e}")


async def test_network_connectivity():
    """测试网络连通性检查"""
    print("\n=== 测试网络连通性检查 ===")
    
    try:
        network_status = await _check_network_connectivity()
        print(f"网络状态: {network_status}")
        
        if network_status.get("connected"):
            print(f"✓ 网络连通正常")
        else:
            print(f"✗ 网络连通异常: {network_status.get('status')}")
            
        if network_status.get("error"):
            print(f"错误信息: {network_status.get('error')}")
            
    except Exception as e:
        print(f"测试异常: {e}")


async def main():
    """主测试函数"""
    print("开始测试WARP连接状态检查功能...\n")
    
    await test_warp_status()
    await test_dbus_status()
    await test_network_connectivity()
    
    print("\n测试完成！")


if __name__ == "__main__":
    asyncio.run(main())