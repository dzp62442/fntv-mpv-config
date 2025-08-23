#!/usr/bin/env python3
"""
简化的测试运行器
避免pytest可能的环境问题
"""
import sys
import unittest
from pathlib import Path

# 确保能找到src模块
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

# 导入测试模块
from tests.test_all import *

if __name__ == '__main__':
    # 运行所有测试
    print("运行MPV配置管理工具测试...")
    print("=" * 50)
    
    # 创建测试套件
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules['tests.test_all'])
    
    # 运行测试
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # 输出结果
    print("=" * 50)
    if result.wasSuccessful():
        print("✅ 所有测试通过!")
        sys.exit(0)
    else:
        print("❌ 有测试失败")
        print(f"失败: {len(result.failures)}, 错误: {len(result.errors)}")
        sys.exit(1)
