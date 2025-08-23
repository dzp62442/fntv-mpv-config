"""
下载管理模块
负责从GitHub等源下载文件
"""
import os
import re
import requests
from typing import Optional, List, Dict, Any
from pathlib import Path
import logging
from tqdm import tqdm


class DownloadError(Exception):
    """下载错误异常"""
    pass


class DownloadManager:
    """下载管理器"""
    
    def __init__(self, temp_dir: Path, proxy_url: str = "", enable_proxy: bool = False):
        """
        初始化下载管理器
        
        Args:
            temp_dir: 临时下载目录
            proxy_url: GitHub代理地址
            enable_proxy: 是否启用代理
        """
        self.temp_dir = Path(temp_dir)
        self.proxy_url = proxy_url.rstrip('/')  # 移除末尾的斜杠
        self.enable_proxy = enable_proxy
        self.session = requests.Session()
        self.logger = logging.getLogger(__name__)
        
        # 创建临时目录
        self.temp_dir.mkdir(parents=True, exist_ok=True)
    
    def download_dependency(self, name: str, config: Dict[str, Any]) -> Path:
        """
        下载依赖项
        
        Args:
            name: 依赖项名称
            config: 依赖项配置
            
        Returns:
            下载文件的路径
            
        Raises:
            DownloadError: 下载失败
        """
        self.logger.info(f"开始下载 {name}")
        
        try:
            # 获取下载URL
            download_url = self._get_download_url(config)
            if not download_url:
                raise DownloadError(f"无法获取 {name} 的下载链接")
            
            # 确定文件名
            filename = self._get_filename(config, download_url)
            file_path = self.temp_dir / filename
            
            # 如果文件已存在且大小正确，跳过下载
            if file_path.exists() and self._verify_file(file_path, download_url):
                self.logger.info(f"{name} 文件已存在，跳过下载")
                return file_path
            
            # 下载文件
            self.logger.info(f"从 {download_url} 下载到 {file_path}")
            self._download_file(download_url, file_path)
            
            self.logger.info(f"{name} 下载完成")
            return file_path
            
        except Exception as e:
            raise DownloadError(f"下载 {name} 失败: {e}")
    
    def _get_download_url(self, config: Dict[str, Any]) -> Optional[str]:
        """
        获取下载URL
        
        Args:
            config: 依赖项配置
            
        Returns:
            下载URL
        """
        base_url = config['url']
        version = config['version']
        filename_pattern = config['filename_pattern']
        file_format = config['format']
        
        if 'github.com' in base_url and '/releases' in base_url:
            return self._get_github_release_url(base_url, version, filename_pattern, file_format)
        else:
            # 其他下载源的处理可以在这里扩展
            raise DownloadError(f"不支持的下载源: {base_url}")
    
    def _get_github_release_url(self, base_url: str, version: str, filename_pattern: str, file_format: str) -> Optional[str]:
        """
        获取GitHub Release的下载URL
        
        Args:
            base_url: GitHub仓库URL
            version: 版本号
            filename_pattern: 文件名模式
            file_format: 文件格式
            
        Returns:
            下载URL
        """
        # 提取仓库信息
        repo_match = re.search(r'github\.com/([^/]+)/([^/]+)', base_url)
        if not repo_match:
            self.logger.error(f"无法解析GitHub仓库URL: {base_url}")
            return None
            
        owner, repo = repo_match.groups()
        self.logger.info(f"解析出仓库: {owner}/{repo}")
        
        # 根据具体的仓库构建准确的文件名
        if owner == "shinchiro" and repo == "mpv-winbuild-cmake":
            # MPV的实际文件名
            filename = f"mpv-dev-x86_64-{version}-git-194ce88.7z"
        elif owner == "tomasklaen" and repo == "uosc":
            # UOSC的文件名
            filename = f"uosc.zip"
        elif owner == "Tony15246" and repo == "uosc_danmaku":
            # uosc_danmaku的文件名
            filename = f"uosc_danmaku.zip"
        else:
            # 通用处理
            if '{version}' in filename_pattern:
                filename = filename_pattern.format(version=version)
            else:
                filename = filename_pattern
            
            if not filename.endswith(f'.{file_format}'):
                filename = f"{filename}.{file_format}"
        
        # 构建直接下载链接
        download_url = f"https://github.com/{owner}/{repo}/releases/download/{version}/{filename}"
        
        # 如果启用代理，添加代理前缀
        if self.enable_proxy and self.proxy_url:
            download_url = f"{self.proxy_url}/{download_url}"
        
        self.logger.info(f"构建的下载链接: {download_url}")
        return download_url
    
    def _get_filename(self, config: Dict[str, Any], download_url: str) -> str:
        """
        确定下载文件名
        
        Args:
            config: 依赖项配置
            download_url: 下载URL
            
        Returns:
            文件名
        """
        # 从URL中提取文件名
        filename = download_url.split('/')[-1]
        
        # 如果文件名不包含格式，添加格式
        if not filename.endswith(f".{config['format']}"):
            filename = f"{config['filename_pattern']}.{config['format']}"
        
        return filename
    
    def _verify_file(self, file_path: Path, download_url: str) -> bool:
        """
        验证文件是否有效
        
        Args:
            file_path: 文件路径
            download_url: 下载URL
            
        Returns:
            是否有效
        """
        try:
            # 简单的大小验证
            response = self.session.head(download_url)
            remote_size = int(response.headers.get('content-length', 0))
            local_size = file_path.stat().st_size
            
            return remote_size == 0 or local_size == remote_size
        except:
            return False
    
    def _download_file(self, url: str, file_path: Path, chunk_size: int = 8192):
        """
        下载文件
        
        Args:
            url: 下载URL
            file_path: 保存路径
            chunk_size: 块大小
        """
        response = self.session.get(url, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        
        # 创建进度条
        # 在CI环境中使用简化的进度条配置
        progress_bar = tqdm(
            total=total_size,
            unit='B',
            unit_scale=True,
            unit_divisor=1024,
            desc=file_path.name,
            disable=total_size == 0,  # 如果无法获取总大小，禁用进度条
            ascii=True,  # 在CI环境中使用ASCII字符
            ncols=80,  # 限制宽度，避免在CI中显示异常
        )
        
        try:
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=chunk_size):
                    if chunk:
                        f.write(chunk)
                        progress_bar.update(len(chunk))
        finally:
            progress_bar.close()
        
        # 下载完成后记录日志
        if total_size > 0:
            self.logger.info(f"下载完成: {file_path.name} ({total_size / 1024 / 1024:.1f} MB)")
        else:
            self.logger.info(f"下载完成: {file_path.name}")
    
    def cleanup(self):
        """清理临时文件"""
        try:
            import shutil
            if self.temp_dir.exists():
                shutil.rmtree(self.temp_dir)
        except Exception as e:
            self.logger.warning(f"清理临时文件失败: {e}")
