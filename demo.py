#!/usr/bin/env python3
"""
演示脚本 - 展示MPV配置管理工具的基本功能
"""

import sys
import tempfile
import json
from pathlib import Path

# 添加src目录到Python路径
current_dir = Path(__file__).parent
src_dir = current_dir / 'src'
sys.path.insert(0, str(src_dir))

from src.main import MPVConfigManager


def create_demo_config():
    """创建演示配置文件"""
    demo_config = {
        "name": "demo-mpv-config",
        "version": "1.0.0",
        "config": {
            "output_dir": "./demo_output",
            "temp_dir": "./demo_temp",
            "custom_config_dir": "./custom_config"
        },
        "dependencies": {
            "uosc": {
                "name": "uosc插件",
                "url": "https://github.com/tomasklaen/uosc/releases",
                "version": "5.11.0",
                "filename_pattern": "uosc",
                "format": "7z",
                "enabled": True,
                "install_rules": [
                    {
                        "from": "scripts",
                        "to": "scripts",
                        "filter": ["**/*.lua"]
                    }
                ]
            }
        }
    }
    
    with open("demo_package.json", 'w', encoding='utf-8') as f:
        json.dump(demo_config, f, indent=2, ensure_ascii=False)
    
    print("演示配置文件已创建: demo_package.json")


def demo_list_dependencies():
    """演示列出依赖项功能"""
    print("\n=== 演示: 列出依赖项 ===")
    manager = MPVConfigManager("demo_package.json", "INFO")
    manager.list_dependencies()


def demo_enable_disable():
    """演示启用/禁用依赖项功能"""
    print("\n=== 演示: 启用/禁用依赖项 ===")
    manager = MPVConfigManager("demo_package.json", "INFO")
    
    print("禁用uosc插件:")
    manager.disable_dependency("uosc")
    
    print("重新启用uosc插件:")
    manager.enable_dependency("uosc")


def demo_dry_run():
    """演示干运行（只下载不安装）"""
    print("\n=== 演示: 干运行（只下载） ===")
    manager = MPVConfigManager("demo_package.json", "INFO")
    
    # 只下载，不安装
    success = manager.run(
        dependencies=["uosc"],
        skip_install=True,
        create_package=False,
        cleanup=False
    )
    
    if success:
        print("干运行完成，文件已下载到临时目录")
    else:
        print("干运行失败")


def main():
    """主演示函数"""
    print("MPV配置管理工具 - 演示程序")
    print("=" * 40)
    
    try:
        # 创建演示配置
        create_demo_config()
        
        # 演示各项功能
        demo_list_dependencies()
        demo_enable_disable()
        
        # 询问是否执行下载演示
        response = input("\n是否要演示下载功能？这会从网络下载文件 (y/N): ")
        if response.lower() in ['y', 'yes']:
            demo_dry_run()
        
        print("\n演示完成！")
        
        # 清理演示文件
        cleanup_response = input("是否清理演示文件？ (Y/n): ")
        if cleanup_response.lower() not in ['n', 'no']:
            import os
            import shutil
            
            files_to_remove = [
                "demo_package.json",
                "demo_output",
                "demo_temp"
            ]
            
            for item in files_to_remove:
                if os.path.exists(item):
                    if os.path.isfile(item):
                        os.remove(item)
                    else:
                        shutil.rmtree(item)
                    print(f"已删除: {item}")
            
            print("清理完成！")
    
    except KeyboardInterrupt:
        print("\n演示被用户中断")
    except Exception as e:
        print(f"演示过程中出现错误: {e}")


if __name__ == '__main__':
    main()
