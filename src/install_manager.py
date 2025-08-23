"""
安装管理模块
负责将解压的文件按照规则安装到目标位置
"""
import shutil
import fnmatch
from typing import Dict, Any, List, Optional
from pathlib import Path
import logging


class InstallError(Exception):
    """安装错误异常"""
    pass


class InstallManager:
    """安装管理器"""
    
    def __init__(self, output_dir: Path, custom_config_dir: Path, project_name: str):
        """
        初始化安装管理器
        
        Args:
            output_dir: 输出目录
            custom_config_dir: 自定义配置目录
            project_name: 项目名称，用于创建子目录
        """
        self.base_output_dir = Path(output_dir)
        self.output_dir = self.base_output_dir / project_name  # 在输出目录下创建项目子目录
        self.custom_config_dir = Path(custom_config_dir)
        self.project_name = project_name
        self.logger = logging.getLogger(__name__)
        self.common_config_installed = False  # 标记是否已安装通用配置
        
        # 创建输出目录
        self.base_output_dir.mkdir(parents=True, exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.portable_config_dir = self.output_dir / "portable_config"
        self.portable_config_dir.mkdir(parents=True, exist_ok=True)
    
    def install_dependency(self, name: str, config: Dict[str, Any], extracted_path: Optional[Path] = None):
        """
        安装依赖项
        
        Args:
            name: 依赖项名称
            config: 依赖项配置
            extracted_path: 解压后的路径，可以为None（仅安装自定义配置）
        """
        self.logger.info(f"开始安装 {name}")
        
        try:
            # 获取安装规则
            install_rules = config.get('install_rules', [])
            
            if extracted_path and install_rules:
                # 根据规则复制文件
                for rule in install_rules:
                    self._apply_install_rule(name, rule, extracted_path)
            elif not extracted_path:
                self.logger.info(f"{name} 没有解压内容，仅安装自定义配置")
            else:
                self.logger.warning(f"{name} 没有定义安装规则，跳过文件安装")
            
            # 安装自定义配置
            self._install_custom_config(name)
            
            self.logger.info(f"{name} 安装完成")
            
        except Exception as e:
            raise InstallError(f"安装 {name} 失败: {e}")
    
    def _apply_install_rule(self, name: str, rule: Dict[str, Any], source_base: Path):
        """
        应用单个安装规则
        
        Args:
            name: 依赖项名称
            rule: 安装规则
            source_base: 源目录基础路径
        """
        source_rel = rule['from']
        target_rel = rule['to']
        filters = rule.get('filter', ['**/*'])
        
        # 构建完整路径
        source_path = source_base / source_rel if source_rel else source_base
        
        # 根据目标路径决定是放在根目录还是portable_config目录
        if target_rel.startswith('portable_config/'):
            # 如果目标路径明确指定了portable_config，则使用指定的路径
            target_path = self.output_dir / target_rel
        elif target_rel == '' or target_rel == '.':
            # 如果目标是空或当前目录，则放在输出根目录
            target_path = self.output_dir
        elif target_rel == 'mpv':
            # mpv子目录应该放在根目录下
            target_path = self.output_dir / target_rel
        else:
            # 其他情况默认放在portable_config目录下
            target_path = self.portable_config_dir / target_rel
        
        self.logger.debug(f"应用规则: {source_path} -> {target_path}")
        
        if not source_path.exists():
            self.logger.warning(f"源路径不存在: {source_path}")
            return
        
        # 创建目标目录
        target_path.mkdir(parents=True, exist_ok=True)
        
        # 根据过滤器复制文件
        for filter_pattern in filters:
            self._copy_filtered_files(source_path, target_path, filter_pattern)
    
    def _copy_filtered_files(self, source_path: Path, target_path: Path, pattern: str):
        """
        根据模式复制文件
        
        Args:
            source_path: 源路径
            target_path: 目标路径
            pattern: 文件模式
        """
        if source_path.is_file():
            # 如果源是文件，直接检查是否匹配模式
            if fnmatch.fnmatch(source_path.name, pattern):
                target_file = target_path / source_path.name
                self._copy_file(source_path, target_file)
        else:
            # 如果源是目录，遍历所有文件
            self._copy_directory_filtered(source_path, target_path, pattern)
    
    def _copy_directory_filtered(self, source_dir: Path, target_dir: Path, pattern: str):
        """
        递归复制目录中匹配模式的文件
        
        Args:
            source_dir: 源目录
            target_dir: 目标目录
            pattern: 文件模式
        """
        for item in source_dir.rglob('*'):
            if item.is_file():
                # 计算相对路径
                rel_path = item.relative_to(source_dir)
                
                # 检查文件是否匹配模式
                if self._matches_pattern(str(rel_path), pattern):
                    target_file = target_dir / rel_path
                    target_file.parent.mkdir(parents=True, exist_ok=True)
                    self._copy_file(item, target_file)
    
    def _matches_pattern(self, file_path: str, pattern: str) -> bool:
        """
        检查文件路径是否匹配模式
        
        Args:
            file_path: 文件路径
            pattern: 模式
            
        Returns:
            是否匹配
        """
        # 处理不同类型的模式
        if pattern == '**/*':
            return True
        elif pattern.startswith('**/'):
            # 匹配任意深度的特定文件
            file_pattern = pattern[3:]
            return fnmatch.fnmatch(Path(file_path).name, file_pattern)
        elif pattern.endswith('/**'):
            # 匹配特定目录下的所有文件
            dir_pattern = pattern[:-3]
            return file_path.startswith(dir_pattern)
        else:
            # 普通模式匹配
            return fnmatch.fnmatch(file_path, pattern)
    
    def _copy_file(self, source: Path, target: Path):
        """
        复制单个文件
        
        Args:
            source: 源文件
            target: 目标文件
        """
        try:
            # 确保目标目录存在
            target.parent.mkdir(parents=True, exist_ok=True)
            
            # 复制文件
            shutil.copy2(source, target)
            self.logger.debug(f"已复制: {source} -> {target}")
            
        except Exception as e:
            self.logger.error(f"复制文件失败: {source} -> {target}, 错误: {e}")
            raise
    
    def _install_custom_config(self, name: str):
        """
        安装自定义配置文件
        
        Args:
            name: 依赖项名称
        """
        # 检查通用自定义配置目录
        custom_dir = self.custom_config_dir / name
        
        if custom_dir.exists():
            self.logger.info(f"安装 {name} 的自定义配置")
            
            try:
                # 递归复制自定义配置到portable_config
                for item in custom_dir.rglob('*'):
                    if item.is_file():
                        rel_path = item.relative_to(custom_dir)
                        target_file = self.portable_config_dir / rel_path
                        self._copy_file(item, target_file)
            
            except Exception as e:
                self.logger.error(f"安装 {name} 自定义配置失败: {e}")
                raise
        
        # 只在第一次调用时安装通用配置文件
        if not self.common_config_installed:
            self._install_common_config()
            self.common_config_installed = True
    
    def _install_common_config(self):
        """
        安装通用配置文件
        """
        self.logger.info("安装通用配置文件")
        
        # 安装根目录级别的自定义配置
        root_custom_files = [
            'danmaku-history.json',
            'settings.xml'
        ]
        
        for filename in root_custom_files:
            custom_file = self.custom_config_dir / filename
            if custom_file.exists():
                target_file = self.portable_config_dir / filename
                self._copy_file(custom_file, target_file)
                self.logger.debug(f"已复制通用配置: {filename}")
        
        # 检查并创建script-opts配置文件
        script_opts_dir = self.portable_config_dir / 'script-opts'
        script_opts_dir.mkdir(parents=True, exist_ok=True)
        
        # 复制uosc_danmaku配置
        uosc_danmaku_conf = self.custom_config_dir / 'uosc_danmaku.conf'
        if uosc_danmaku_conf.exists():
            target_conf = script_opts_dir / 'uosc_danmaku.conf'
            self._copy_file(uosc_danmaku_conf, target_conf)
    
    def create_package(self) -> Path:
        """
        创建最终的安装包
        
        Returns:
            安装包路径
        """
        self.logger.info("创建安装包")
        
        package_name = f"mpv-package-{self._get_timestamp()}"
        # 打包文件放在根输出目录，而不是项目子目录
        package_path = self.base_output_dir / f"{package_name}.zip"
        
        try:
            import zipfile
            
            with zipfile.ZipFile(package_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                # 添加所有文件到压缩包
                for file_path in self.output_dir.rglob('*'):
                    if file_path.is_file():
                        arcname = file_path.relative_to(self.output_dir)
                        zipf.write(file_path, arcname)
            
            self.logger.info(f"安装包创建完成: {package_path}")
            return package_path
            
        except Exception as e:
            raise InstallError(f"创建安装包失败: {e}")
    
    def _get_timestamp(self) -> str:
        """获取时间戳"""
        from datetime import datetime
        return datetime.now().strftime("%Y%m%d_%H%M%S")
    
    def cleanup_output(self):
        """清理输出目录"""
        try:
            if self.output_dir.exists():
                shutil.rmtree(self.output_dir)
                self.logger.info(f"已清理输出目录: {self.output_dir}")
        except Exception as e:
            self.logger.warning(f"清理输出目录失败: {e}")
