#!/usr/bin/env python3
"""
测试脚本：验证构建后的目录结构是否符合预期
"""
import os
from pathlib import Path

def check_directory_structure():
    """检查输出目录结构"""
    output_dir = Path("output/fntv-mpv-config")
    
    if not output_dir.exists():
        print("❌ 输出目录不存在")
        return False
    
    expected_structure = {
        # 根目录文件
        "mpv.exe": False,
        "mpv.com": False,
        "d3dcompiler_43.dll": False,
        
        # mpv子目录
        "mpv/fonts.conf": False,
        
        # portable_config目录
        "portable_config/danmaku-history.json": False,
        "portable_config/input.conf": False,
        "portable_config/settings.xml": False,
        
        # fonts目录
        "portable_config/fonts/uosc_icons.otf": False,
        "portable_config/fonts/uosc_textures.ttf": False,
        
        # script-opts目录
        "portable_config/script-opts/uosc.conf": False,
        "portable_config/script-opts/uosc_danmaku.conf": False,
        
        # scripts目录
        "portable_config/scripts/uosc/main.lua": False,
        "portable_config/scripts/uosc_danmaku/main.lua": False,
    }
    
    print("🔍 检查目录结构...")
    
    for file_path, _ in expected_structure.items():
        full_path = output_dir / file_path
        if full_path.exists():
            expected_structure[file_path] = True
            print(f"✅ {file_path}")
        else:
            print(f"❌ {file_path}")
    
    # 统计结果
    found = sum(expected_structure.values())
    total = len(expected_structure)
    
    print(f"\n📊 结果: {found}/{total} 个文件/目录存在")
    
    if found == total:
        print("🎉 目录结构完全符合预期！")
        return True
    else:
        print("⚠️ 有些文件缺失，需要检查配置")
        return False

def list_actual_structure():
    """列出实际的目录结构"""
    output_dir = Path("output")
    
    if not output_dir.exists():
        print("输出目录不存在")
        return
    
    print("\n📁 实际目录结构:")
    for root, dirs, files in os.walk(output_dir):
        level = root.replace(str(output_dir), '').count(os.sep)
        indent = ' ' * 2 * level
        print(f"{indent}{os.path.basename(root)}/")
        subindent = ' ' * 2 * (level + 1)
        for file in files:
            print(f"{subindent}{file}")

if __name__ == "__main__":
    check_directory_structure()
    list_actual_structure()
