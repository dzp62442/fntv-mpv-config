"""
测试模块
包含各个组件的单元测试
"""
import unittest
import tempfile
import json
from pathlib import Path
import sys
import os

# 添加src目录到Python路径
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from config_manager import ConfigManager, ConfigError
from download_manager import DownloadManager
from extract_manager import ExtractManager
from install_manager import InstallManager


class TestConfigManager(unittest.TestCase):
    """配置管理器测试"""
    
    def setUp(self):
        """设置测试环境"""
        self.temp_dir = tempfile.mkdtemp()
        self.config_path = Path(self.temp_dir) / "test_package.json"
        
        # 创建测试配置
        self.test_config = {
            "name": "test-config",
            "version": "1.0.0",
            "config": {
                "output_dir": "./output",
                "temp_dir": "./temp",
                "custom_config_dir": "./custom_config"
            },
            "dependencies": {
                "test_dep": {
                    "name": "测试依赖",
                    "url": "https://example.com",
                    "version": "1.0.0",
                    "filename_pattern": "test",
                    "format": "zip",
                    "enabled": True,
                    "install_rules": []
                }
            }
        }
        
        with open(self.config_path, 'w', encoding='utf-8') as f:
            json.dump(self.test_config, f)
    
    def test_load_config(self):
        """测试配置加载"""
        manager = ConfigManager(str(self.config_path))
        config = manager.load_config()
        
        self.assertEqual(config['name'], 'test-config')
        self.assertEqual(config['version'], '1.0.0')
    
    def test_get_enabled_dependencies(self):
        """测试获取已启用的依赖项"""
        manager = ConfigManager(str(self.config_path))
        manager.load_config()
        
        deps = manager.get_enabled_dependencies()
        self.assertIn('test_dep', deps)
        self.assertTrue(deps['test_dep']['enabled'])
    
    def test_config_validation(self):
        """测试配置验证"""
        # 创建无效配置
        invalid_config = {"invalid": "config"}
        invalid_path = Path(self.temp_dir) / "invalid.json"
        
        with open(invalid_path, 'w') as f:
            json.dump(invalid_config, f)
        
        manager = ConfigManager(str(invalid_path))
        
        with self.assertRaises(ConfigError):
            manager.load_config()


class TestDownloadManager(unittest.TestCase):
    """下载管理器测试"""
    
    def setUp(self):
        """设置测试环境"""
        self.temp_dir = tempfile.mkdtemp()
        self.manager = DownloadManager(Path(self.temp_dir))
    
    def test_get_github_release_url(self):
        """测试GitHub Release URL获取"""
        # 这个测试需要网络连接，可以使用mock
        config = {
            'url': 'https://github.com/tomasklaen/uosc/releases',
            'version': '5.11.0',
            'filename_pattern': 'uosc',
            'format': '7z'
        }
        
        # 实际测试时可能需要mock requests
        url = self.manager._get_github_release_url(
            config['url'], 
            config['version'], 
            config['filename_pattern'], 
            config['format']
        )
        
        # 如果有网络连接，应该能获取到URL
        if url:
            self.assertIn('github.com', url)
            self.assertIn('uosc', url)


class TestExtractManager(unittest.TestCase):
    """解压管理器测试"""
    
    def setUp(self):
        """设置测试环境"""
        self.temp_dir = tempfile.mkdtemp()
        self.manager = ExtractManager(Path(self.temp_dir))
    
    def test_get_format(self):
        """测试格式识别"""
        self.assertEqual(self.manager._get_format(Path("test.zip")), "zip")
        self.assertEqual(self.manager._get_format(Path("test.7z")), "7z")
        self.assertEqual(self.manager._get_format(Path("test.tar.gz")), "gz")


class TestInstallManager(unittest.TestCase):
    """安装管理器测试"""
    
    def setUp(self):
        """设置测试环境"""
        self.temp_dir = tempfile.mkdtemp()
        self.output_dir = Path(self.temp_dir) / "output"
        self.custom_config_dir = Path(self.temp_dir) / "custom_config"
        
        self.manager = InstallManager(self.output_dir, self.custom_config_dir)
    
    def test_matches_pattern(self):
        """测试模式匹配"""
        self.assertTrue(self.manager._matches_pattern("test.lua", "*.lua"))
        self.assertTrue(self.manager._matches_pattern("dir/test.lua", "**/*.lua"))
        self.assertFalse(self.manager._matches_pattern("test.txt", "*.lua"))


if __name__ == '__main__':
    unittest.main()
