#!/bin/bash
# ============================================================
# 通用函数库 - NapCat/AstrBot/宝塔面板 一键部署工具
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/deploy-helper.log"
DEPLOY_STATUS_FILE="/tmp/deploy-status.json"
SERVICE_INFO_FILE="/tmp/deploy-service-info.json"

# ---------- 工具函数 ----------

log() {
    local level=$1
    local msg=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO") echo -e "${GREEN}[INFO]${NC} ${msg}" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} ${msg}" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} ${msg}" ;;
        "STEP") echo -e "${CYAN}[STEP]${NC} ${msg}" ;;
        *) echo -e "${msg}" ;;
    esac
    echo "[${timestamp}] [${level}] ${msg}" >> "${LOG_FILE}"
}

# 写入日志到文件（供 Web 后端读取）
write_log() {
    local msg=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${msg}" >> "${LOG_FILE}"
    echo "${msg}"
}

# 更新部署状态 JSON
update_status() {
    local service=$1
    local status=$2
    local message=$3
    local tmp=$(mktemp)
    if [ -f "${DEPLOY_STATUS_FILE}" ]; then
        cat "${DEPLOY_STATUS_FILE}" > "${tmp}"
    else
        echo "{}" > "${tmp}"
    fi
    # 使用 python3 更新 JSON (如果可用)
    if command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
try:
    with open('${tmp}', 'r') as f:
        data = json.load(f)
except:
    data = {}
data['${service}'] = {'status': '${status}', 'message': '${message}', 'timestamp': '$(date +%s)'}
with open('${tmp}', 'w') as f:
    json.dump(data, f, indent=2)
"
    else
        # 简单回退
        echo "{\"${service}\": {\"status\": \"${status}\", \"message\": \"${message}\"}}" > "${tmp}"
    fi
    cat "${tmp}" > "${DEPLOY_STATUS_FILE}"
    rm -f "${tmp}"
}

# 保存服务信息（部署完成后获取的关键信息）
save_service_info() {
    local service=$1
    local key=$2
    local value=$3
    local tmp=$(mktemp)
    if [ -f "${SERVICE_INFO_FILE}" ]; then
        cat "${SERVICE_INFO_FILE}" > "${tmp}"
    else
        echo "{}" > "${tmp}"
    fi
    if command -v python3 &>/dev/null; then
        python3 -c "
import json
try:
    with open('${tmp}', 'r') as f:
        data = json.load(f)
except:
    data = {}
if '${service}' not in data:
    data['${service}'] = {}
data['${service}']['${key}'] = '${value}'
with open('${tmp}', 'w') as f:
    json.dump(data, f, indent=2)
"
    else
        echo "{\"${service}\": {\"${key}\": \"${value}\"}}" > "${tmp}"
    fi
    cat "${tmp}" > "${SERVICE_INFO_FILE}"
    rm -f "${tmp}"
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &>/dev/null; then
        log "ERROR" "缺少命令: $1"
        return 1
    fi
    return 0
}

# 安装系统依赖
install_deps() {
    log "STEP" "检查并安装系统依赖..."
    if command -v apt &>/dev/null; then
        apt update -y >> "${LOG_FILE}" 2>&1
        apt install -y curl wget git python3 python3-pip xvfb unzip jq sudo >> "${LOG_FILE}" 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y curl wget git python3 python3-pip xvfb unzip jq sudo >> "${LOG_FILE}" 2>&1
    else
        log "WARN" "不支持的系统包管理器，请手动安装依赖"
    fi
    log "INFO" "系统依赖检查完成"
}

# 检查系统架构
check_arch() {
    local arch=$(uname -m)
    if [ "$arch" != "x86_64" ] && [ "$arch" != "aarch64" ]; then
        log "WARN" "当前架构: $arch，部分组件可能不支持"
    else
        log "INFO" "系统架构: $arch ✓"
    fi
}

# 检查是否为 root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log "ERROR" "请使用 root 权限运行此脚本 (sudo bash main.sh)"
        exit 1
    fi
}

# 等待服务启动
wait_for_port() {
    local port=$1
    local timeout=${2:-60}
    local elapsed=0
    log "INFO" "等待端口 ${port} 就绪（超时 ${timeout}s）..."
    while [ $elapsed -lt $timeout ]; do
        if ss -tlnp | grep -q ":${port} "; then
            log "INFO" "端口 ${port} 已就绪 ✓"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    log "WARN" "端口 ${port} 等待超时"
    return 1
}

# 获取本机公网 IP
get_public_ip() {
    curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "无法获取公网IP"
}

# 读取配置文件
read_config() {
    local key=$1
    local config_file="/workspace/napcat-astrbot-baota-deploy/config.json"
    if [ ! -f "${config_file}" ]; then
        config_file="$(dirname "$0")/../config.json"
    fi
    if command -v python3 &>/dev/null; then
        python3 -c "import json; print(json.load(open('${config_file}'))${key})" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# 获取服务信息
get_service_info() {
    local service=$1
    if [ -f "${SERVICE_INFO_FILE}" ]; then
        cat "${SERVICE_INFO_FILE}"
    else
        echo "{}"
    fi
}