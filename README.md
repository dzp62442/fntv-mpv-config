# MPV配置管理工具

一个用于自动下载、配置和打包MPV播放器及其插件的Python工具。支持版本管理、插件热插拔和GitHub Actions自动化构建。

## 功能特点

- 🎯 **自动化管理**: 自动下载MPV播放器和插件
- 🔧 **版本控制**: 通过配置文件管理所有组件版本
- 🔌 **插件热插拔**: 轻松启用/禁用插件
- 📦 **智能打包**: 自动创建便携式安装包
- 🛠️ **自定义配置**: 支持自定义配置文件
- 🚀 **CI/CD支持**: GitHub Actions每日自动构建

## 项目结构

```
fntv-mpv-config/
├── src/                    # 源代码目录
│   ├── __init__.py
│   ├── main.py            # 主程序
│   ├── config_manager.py  # 配置管理
│   ├── download_manager.py # 下载管理
│   ├── extract_manager.py # 解压管理
│   ├── install_manager.py # 安装管理
│   └── log_manager.py     # 日志管理
├── custom_config/         # 自定义配置目录
│   ├── mpv/
│   │   └── input.conf     # MPV快捷键配置
│   └── uosc/
│       └── script-opts/
│           └── uosc.conf  # UOSC插件配置
├── tests/                 # 测试目录
├── .github/workflows/     # GitHub Actions工作流
├── package.json          # 主配置文件
├── requirements.txt      # Python依赖
├── run.py               # 运行脚本
└── README.md           # 文档
```

## 快速开始

### 1. 环境准备

```bash
# 克隆仓库
git clone https://github.com/your-username/fntv-mpv-config.git
cd fntv-mpv-config

# 安装Python依赖
pip install -r requirements.txt
```

### 2. 配置管理

编辑 `package.json` 文件来配置版本和下载源：

```json
{
  "dependencies": {
    "mpv": {
      "version": "20250823",
      "enabled": true
    },
    "uosc": {
      "version": "5.11.0",
      "enabled": true
    },
    "uosc_danmaku": {
      "version": "v1.3.2",
      "enabled": false
    }
  }
}
```

### 3. 基本使用

```bash
# 处理所有启用的依赖项
python run.py

# 只处理指定的依赖项
python run.py --deps mpv uosc

# 列出所有依赖项
python run.py --list

# 启用/禁用依赖项
python run.py --enable uosc_danmaku
python run.py --disable uosc_danmaku

# 跳过下载，只安装（用于调试）
python run.py --skip-download

# 只下载，不安装
python run.py --skip-install
```

## 配置文件详解

### package.json 主配置文件

```json
{
  "name": "fntv-mpv-config",
  "version": "1.0.0",
  "config": {
    "output_dir": "./output",          // 输出目录
    "temp_dir": "./temp",              // 临时目录
    "custom_config_dir": "./custom_config"  // 自定义配置目录
  },
  "dependencies": {
    "mpv": {
      "name": "mpv播放器",
      "url": "https://github.com/shinchiro/mpv-winbuild-cmake/releases",
      "version": "20250823",
      "filename_pattern": "mpv-x86_64-20250823",
      "format": "7z",
      "enabled": true,
      "install_rules": [
        {
          "from": "uosc/conf",          // 源目录
          "to": "script-opts",          // 目标目录
          "filter": ["**/*"]            // 文件过滤器
        }
      ]
    }
  }
}
```

### 安装规则说明

- `from`: 源目录路径（相对于解压后的根目录）
- `to`: 目标目录路径（相对于portable_config目录）
- `filter`: 文件过滤器数组，支持glob模式
  - `**/*`: 所有文件
  - `*.lua`: 所有Lua文件
  - `**/script-opts/**`: script-opts目录下的所有文件

## 自定义配置

在 `custom_config` 目录下放置自定义配置文件，程序会自动将它们复制到最终的portable_config目录中。

### 目录结构示例

```
custom_config/
├── mpv/
│   ├── input.conf        # 快捷键配置
│   └── mpv.conf          # MPV主配置
├── uosc/
│   └── script-opts/
│       └── uosc.conf     # UOSC插件配置
└── scripts/
    └── custom.lua        # 自定义脚本
```

## GitHub Actions 自动化

项目包含GitHub Actions工作流，支持：

- **每日自动构建**: 每天自动检查更新并构建
- **手动触发**: 可以手动触发构建
- **自动发布**: 构建完成后自动创建Release

### 配置说明

工作流文件位于 `.github/workflows/daily-build.yml`，主要特性：

- 使用Windows环境进行构建
- 自动上传构建产物
- 创建带时间戳的Release
- 支持构建失败时的错误处理

## 开发指南

### 模块设计

项目采用模块化设计，各模块职责明确：

1. **ConfigManager**: 配置文件的读取、验证和管理
2. **DownloadManager**: 处理各种下载源的文件下载
3. **ExtractManager**: 支持多种压缩格式的解压
4. **InstallManager**: 根据规则安装文件和配置
5. **LogManager**: 统一的日志管理

### 扩展性

- **添加新的下载源**: 在DownloadManager中扩展
- **支持新的压缩格式**: 在ExtractManager中添加处理器
- **自定义安装规则**: 修改InstallManager的规则处理逻辑

### 调试技巧

```bash
# 启用详细日志
python run.py --log-level DEBUG

# 跳过下载步骤（用于测试安装逻辑）
python run.py --skip-download

# 不清理临时文件（用于检查中间结果）
python run.py --no-cleanup
```

## 运行测试

```bash
# 运行所有测试
python -m pytest tests/

# 运行特定测试
python tests/test_all.py
```

## 常见问题

### Q: 下载失败怎么办？
A: 检查网络连接，确认GitHub访问正常。可以使用`--log-level DEBUG`查看详细错误信息。

### Q: 如何添加新的插件？
A: 在`package.json`的`dependencies`中添加新的插件配置，包括下载地址、版本号和安装规则。

### Q: 自定义配置不生效？
A: 确认配置文件放在正确的`custom_config`目录结构中，并且文件名和路径正确。

### Q: GitHub Actions构建失败？
A: 检查`package.json`中的版本号是否存在，网络访问是否正常，依赖项是否正确安装。

## 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 贡献指南

欢迎提交Issue和Pull Request来改进这个项目：

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开Pull Request

## 更新日志

### v1.0.0 (2025-08-24)
- 初始版本发布
- 支持MPV、UOSC、UOSC_DANMAKU的自动下载和配置
- 实现GitHub Actions自动化构建
- 提供完整的配置管理功能
fntv-electron配套mpv配置
