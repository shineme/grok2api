#!/usr/bin/env python3
"""
测试WARP状态检查API端点
"""

import asyncio
import aiohttp
import json


async def test_health_endpoint():
    """测试健康检查端点"""
    print("=== 测试健康检查端点 ===")
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get('http://localhost:8001/health', timeout=aiohttp.ClientTimeout(total=10)) as response:
                if response.status == 200:
                    data = await response.json()
                    print(f"健康检查响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
                    
                    if 'warp_connected' in data:
                        warp_status = data['warp_connected']
                        if warp_status is True:
                            print("✓ WARP已连接")
                        elif warp_status is False:
                            print("✗ WARP未连接")
                        else:
                            print("? WARP状态未知")
                    else:
                        print("! 响应中缺少warp_connected字段")
                else:
                    print(f"✗ 请求失败，状态码: {response.status}")
                    
    except aiohttp.ClientConnectorError:
        print("✗ 无法连接到服务器，请确保应用正在运行")
    except asyncio.TimeoutError:
        print("✗ 请求超时")
    except Exception as e:
        print(f"✗ 测试异常: {e}")


async def test_system_status_endpoint():
    """测试系统状态端点（需要认证）"""
    print("\n=== 测试系统状态端点 ===")
    print("注意：此端点需要管理员认证，这里只测试未认证的情况")
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get('http://localhost:8001/api/system/status', timeout=aiohttp.ClientTimeout(total=10)) as response:
                if response.status == 401:
                    print("✓ 端点存在且需要认证（符合预期）")
                elif response.status == 200:
                    data = await response.json()
                    print(f"意外成功响应: {json.dumps(data, indent=2, ensure_ascii=False)}")
                else:
                    print(f"响应状态码: {response.status}")
                    
    except aiohttp.ClientConnectorError:
        print("✗ 无法连接到服务器，请确保应用正在运行")
    except asyncio.TimeoutError:
        print("✗ 请求超时")
    except Exception as e:
        print(f"✗ 测试异常: {e}")


async def main():
    """主测试函数"""
    print("开始测试WARP状态检查API端点...\n")
    
    await test_health_endpoint()
    await test_system_status_endpoint()
    
    print("\n测试完成！")
    print("\n要测试完整的系统状态功能，请：")
    print("1. 启动应用: python -m uvicorn main:app --host 0.0.0.0 --port 8001")
    print("2. 访问管理后台: http://localhost:8001/login")
    print("3. 使用 admin/admin 登录")
    print("4. 调用 /api/system/status API")


if __name__ == "__main__":
    asyncio.run(main())