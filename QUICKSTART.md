# 快速开始指南

## 系统要求

- Python 3.7+
- Windows 10/11（推荐）
- 网络连接（用于下载文件）

## 安装步骤

### 1. 克隆仓库
```bash
git clone https://github.com/your-username/fntv-mpv-config.git
cd fntv-mpv-config
```

### 2. 安装依赖
```bash
pip install -r requirements.txt
```

### 3. 验证配置
```bash
python validate_config.py
```

## 基本使用

### 快速构建
```bash
# 构建所有启用的组件
python run.py

# 只构建特定组件
python run.py --deps mpv uosc
```

### 管理依赖项
```bash
# 查看所有依赖项
python run.py --list

# 启用/禁用组件
python run.py --enable uosc_danmaku
python run.py --disable uosc_danmaku
```

### 调试模式
```bash
# 详细日志
python run.py --log-level DEBUG

# 只下载不安装
python run.py --skip-install

# 跳过下载直接安装
python run.py --skip-download
```

## 输出结果

构建完成后，在 `output` 目录下会生成：
- `portable_config/` - MPV配置目录
- `mpv-package-[时间戳].zip` - 完整安装包

## 使用生成的MPV包

1. 解压生成的zip文件
2. 运行 `mpv.exe`
3. 享受预配置的播放体验

## 自定义配置

在 `custom_config` 目录下放置你的自定义配置：

```
custom_config/
├── mpv/
│   ├── input.conf     # 快捷键配置
│   └── mpv.conf       # 播放器配置
├── scripts/
│   └── custom.lua     # 自定义脚本
└── uosc/
    └── script-opts/
        └── uosc.conf  # 界面配置
```

## 故障排除

### 下载失败
- 检查网络连接
- 确认GitHub访问正常
- 查看详细日志：`python run.py --log-level DEBUG`

### 配置错误
```bash
# 验证配置文件
python validate_config.py package.json
```

### 清理重建
```bash
# 清理临时文件
rmdir /s temp output
```

## 高级功能

### GitHub Actions自动化
- 提交代码到main分支自动触发构建
- 每日定时构建
- 自动创建Release

### 扩展开发
- 添加新的下载源
- 支持新的压缩格式
- 自定义安装规则

## 技术支持

- 查看README.md获取详细文档
- 提交Issue报告问题
- 贡献代码改进项目
