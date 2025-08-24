"""
本地包功能简化测试
专注于测试核心的本地包功能
"""
import unittest
import tempfile
import shutil
from pathlib import Path
import sys

# 添加src目录到Python路径
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from download_manager import DownloadManager


class TestLocalPackageCore(unittest.TestCase):
    """本地包核心功能测试"""
    
    def setUp(self):
        """设置测试环境"""
        self.temp_dir = tempfile.mkdtemp()
        self.test_dir = Path(self.temp_dir)
        
        # 创建下载管理器
        self.download_manager = DownloadManager(
            temp_dir=self.test_dir / "temp",
            proxy_url="",
            enable_proxy=False
        )
    
    def tearDown(self):
        """清理测试环境"""
        shutil.rmtree(self.temp_dir, ignore_errors=True)
    
    def test_is_local_file_detection(self):
        """测试本地文件检测功能"""
        # 测试local_path配置
        config1 = {"local_path": "./test.zip"}
        self.assertTrue(self.download_manager._is_local_file(config1))
        
        config2 = {"local_path": "/tmp/test.zip"}
        self.assertTrue(self.download_manager._is_local_file(config2))
        
        # 测试url为本地路径
        config3 = {"url": "./test.zip"}
        self.assertTrue(self.download_manager._is_local_file(config3))
        
        config4 = {"url": "C:\\test.zip"}
        self.assertTrue(self.download_manager._is_local_file(config4))
        
        # 测试网络URL
        config5 = {"url": "https://example.com/test.zip"}
        self.assertFalse(self.download_manager._is_local_file(config5))
        
        config6 = {"url": "http://example.com/test.zip"}
        self.assertFalse(self.download_manager._is_local_file(config6))
        
        # 测试空配置
        config7 = {}
        self.assertFalse(self.download_manager._is_local_file(config7))
    
    def test_local_directory_handling(self):
        """测试本地文件夹处理"""
        # 创建测试文件夹结构
        test_plugin_dir = self.test_dir / "test_plugin"
        test_plugin_dir.mkdir()
        (test_plugin_dir / "main.lua").write_text("-- Test plugin")
        (test_plugin_dir / "README.md").write_text("# Test Plugin")
        
        scripts_dir = test_plugin_dir / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "helper.lua").write_text("-- Helper script")
        
        # 配置
        dep_config = {
            "name": "测试插件",
            "local_path": str(test_plugin_dir),
            "version": "1.0.0",
            "filename_pattern": "test_plugin"
        }
        
        # 测试处理
        result_path = self.download_manager._handle_local_directory(
            "test_plugin",
            Path(test_plugin_dir), 
            dep_config
        )
        
        # 验证结果
        expected_path = self.download_manager.temp_dir / "test_plugin_extracted"
        self.assertEqual(result_path, expected_path)
        
        # 验证文件已复制
        self.assertTrue(expected_path.exists())
        self.assertTrue((expected_path / "main.lua").exists())
        self.assertTrue((expected_path / "README.md").exists())
        self.assertTrue((expected_path / "scripts" / "helper.lua").exists())
        
        # 验证文件内容
        content = (expected_path / "main.lua").read_text()
        self.assertEqual(content, "-- Test plugin")


if __name__ == '__main__':
    # 运行测试
    unittest.main(verbosity=2)
