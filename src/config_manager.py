"""
配置管理模块
负责读取和验证 package.json 配置文件
"""
import json
import os
from typing import Dict, Any, List
from pathlib import Path


class ConfigError(Exception):
    """配置错误异常"""
    pass


class ConfigManager:
    """配置管理器"""
    
    def __init__(self, config_path: str = "package.json"):
        """
        初始化配置管理器
        
        Args:
            config_path: 配置文件路径
        """
        self.config_path = Path(config_path)
        self._config = None
        
    def load_config(self) -> Dict[str, Any]:
        """
        加载配置文件
        
        Returns:
            配置字典
            
        Raises:
            ConfigError: 配置文件不存在或格式错误
        """
        if not self.config_path.exists():
            raise ConfigError(f"配置文件不存在: {self.config_path}")
            
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                self._config = json.load(f)
            self._validate_config()
            return self._config
        except json.JSONDecodeError as e:
            raise ConfigError(f"配置文件格式错误: {e}")
    
    def _validate_config(self):
        """验证配置文件格式"""
        if not isinstance(self._config, dict):
            raise ConfigError("配置文件必须是JSON对象")
            
        required_keys = ['name', 'version', 'config', 'dependencies']
        for key in required_keys:
            if key not in self._config:
                raise ConfigError(f"缺少必需的配置项: {key}")
    
    def get_config(self) -> Dict[str, Any]:
        """获取完整配置"""
        if self._config is None:
            self.load_config()
        return self._config
    
    def get_output_dir(self) -> Path:
        """获取输出目录"""
        return Path(self.get_config()['config']['output_dir'])
    
    def get_temp_dir(self) -> Path:
        """获取临时目录"""
        return Path(self.get_config()['config']['temp_dir'])
    
    def get_custom_config_dir(self) -> Path:
        """获取自定义配置目录"""
        return Path(self.get_config()['config']['custom_config_dir'])
    
    def get_enabled_dependencies(self) -> Dict[str, Dict[str, Any]]:
        """获取已启用的依赖项"""
        dependencies = self.get_config()['dependencies']
        return {name: dep for name, dep in dependencies.items() if dep.get('enabled', True)}
    
    def get_dependency(self, name: str) -> Dict[str, Any]:
        """
        获取指定依赖项配置
        
        Args:
            name: 依赖项名称
            
        Returns:
            依赖项配置
            
        Raises:
            ConfigError: 依赖项不存在
        """
        dependencies = self.get_config()['dependencies']
        if name not in dependencies:
            raise ConfigError(f"依赖项不存在: {name}")
        return dependencies[name]
    
    def save_config(self, config: Dict[str, Any]):
        """
        保存配置到文件
        
        Args:
            config: 配置字典
        """
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
            self._config = config
        except Exception as e:
            raise ConfigError(f"保存配置文件失败: {e}")
