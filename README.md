# NapCat / AstrBot / 宝塔面板 一键部署工具

一站式快速部署 QQ 机器人（NapCatQQ + AstrBot）和服务器管理面板（宝塔面板）的 Linux 部署工具。

## 功能特点

- **交互式部署**：选择你需要部署的服务，支持多选
- **多版本支持**：NapCatQQ 支持官方原版和修复版 (Fix) 两种选择
- **实时日志**：Web 管理界面实时显示部署进度和日志
- **自动获取信息**：部署完成后自动获取各服务的关键信息
  - NapCatQQ：WebUI 地址、Token、OneBot 地址、登录二维码
  - AstrBot：Dashboard 地址、API Key
  - 宝塔面板：面板地址、用户名、密码
- **Web 管理界面**：基于 Flask 的 Web 后端，支持在浏览器中查看和管理
- **一键复制**：部署完成后，关键信息可一键复制到剪贴板

## 支持的服务

| 服务 | 说明 | 端口 |
|------|------|------|
| **NapCatQQ** | 基于 NTQQ 的 OneBot 协议实现，QQ 机器人框架 | 6099(WebUI), 3001(OneBot), 3000(HTTP) |
| **AstrBot** | 支持多平台的 LLM 聊天机器人框架 | 6185 |
| **宝塔面板** | Linux 服务器管理面板 | 8888 |

## 快速开始

### 方式一：交互式部署（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/Mangfluff/napcat-astrbot-baota-deploy.git
cd napcat-astrbot-baota-deploy

# 2. 运行部署脚本（需 root 权限）
sudo bash main.sh
```

运行后，按照交互式菜单选择所需部署的服务即可。

### 方式二：命令行部署

```bash
sudo bash main.sh --napcat original --qq 123456789 --astrbot source --baota --web
```

**参数说明：**

| 参数 | 说明 |
|------|------|
| `--napcat <original|fix>` | 部署 NapCatQQ，指定版本 |
| `--astrbot <source|docker>` | 部署 AstrBot，指定部署方式 |
| `--baota` | 部署宝塔面板 |
| `--qq <QQ号>` | 设置 NapCat QQ 号 |
| `--fix-repo <url>` | 修复版 NapCat 仓库地址 |
| `--web` | 启动 Web 管理界面 |
| `--help` | 查看帮助 |

## Web 管理界面

部署完成后，Web 管理界面会自动启动，默认访问地址：`http://<服务器IP>:18080`

功能包括：

- **服务选择**：勾选需要部署的服务，选择 NapCat 版本（原版/修复版）
- **实时日志**：SSE 实时推送部署日志，不同级别彩色显示
- **部署状态**：实时显示各服务的部署进度
- **服务信息**：自动获取并展示各服务的关键信息，支持一键复制
- **登录二维码**：NapCat 启动后自动获取登录二维码

## 部署说明

### NapCatQQ

- **官方原版**：使用 NapNeko 官方安装脚本自动安装
- **修复版 (Fix)**：从你的修复版仓库克隆并安装
- 启动命令：`xvfb-run -a /root/Napcat/opt/QQ/qq --no-sandbox -q <QQ号>`
- WebUI 登录地址：`http://<IP>:6099/webui`

### AstrBot

- **源码部署**：克隆官方仓库，创建 Python 虚拟环境，安装依赖
- **Docker 部署**：使用 Docker Compose 一键部署
- 自动创建 systemd 服务，支持开机自启

### 宝塔面板

- 自动检测系统类型，选择对应安装脚本
- 安装完成后自动获取面板信息

## 项目结构

```
napcat-astrbot-baota-deploy/
├── main.sh                 # 主入口脚本
├── config.json             # 配置文件
├── scripts/
│   ├── common.sh           # 通用函数库
│   ├── install_napcat.sh   # NapCatQQ 安装脚本
│   ├── install_astrbot.sh  # AstrBot 安装脚本
│   └── install_baota.sh    # 宝塔面板安装脚本
├── web/
│   ├── server.py           # Flask Web 后端
│   └── static/
│       ├── index.html      # 前端页面
│       ├── style.css       # 样式
│       └── app.js          # 前端逻辑
└── README.md
```

## 环境要求

- 操作系统：Ubuntu 20+ / Debian 10+ / CentOS 9+
- 架构：x86_64 / aarch64
- 权限：需要 root 权限

## 许可证

MIT License