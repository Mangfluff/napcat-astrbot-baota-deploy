#!/bin/bash
# ============================================================
# AstrBot 安装脚本
# 支持：源码部署 / Docker 部署
# 功能：安装、配置、获取 API Key
# ============================================================

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 默认配置
INSTALL_METHOD="source"
INSTALL_DIR="/opt/AstrBot"
GIT_REPO="https://github.com/AstrBotDevs/AstrBot.git"
ASTRBOT_PORT=6185

# ---------- 参数解析 ----------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --port)
                ASTRBOT_PORT="$2"
                shift 2
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo "  --method <source|docker>    部署方式 (默认: source)"
                echo "  --install-dir <path>        安装目录 (默认: /opt/AstrBot)"
                echo "  --port <port>               服务端口 (默认: 6185)"
                exit 0
                ;;
            *)
                log "ERROR" "未知参数: $1"
                exit 1
                ;;
        esac
    done
}

# ---------- 源码部署 ----------
install_source() {
    log "STEP" "开始源码部署 AstrBot..."
    update_status "astrbot" "installing" "正在源码部署 AstrBot..."

    # 安装系统依赖
    log "INFO" "安装 Python 依赖..."
    if command -v apt &>/dev/null; then
        apt install -y python3 python3-pip python3-venv git >> "${LOG_FILE}" 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y python3 python3-pip git >> "${LOG_FILE}" 2>&1
    fi

    # 克隆仓库
    if [ -d "${INSTALL_DIR}" ]; then
        log "WARN" "安装目录已存在: ${INSTALL_DIR}"
        log "INFO" "将更新现有代码..."
        cd "${INSTALL_DIR}"
        git pull >> "${LOG_FILE}" 2>&1 || true
    else
        log "INFO" "克隆 AstrBot 仓库..."
        mkdir -p "$(dirname "${INSTALL_DIR}")"
        git clone "${GIT_REPO}" "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1
        if [ $? -ne 0 ]; then
            log "ERROR" "克隆仓库失败"
            update_status "astrbot" "failed" "克隆仓库失败"
            return 1
        fi
    fi

    cd "${INSTALL_DIR}"

    # 创建虚拟环境
    log "INFO" "创建 Python 虚拟环境..."
    python3 -m venv venv >> "${LOG_FILE}" 2>&1
    source venv/bin/activate

    # 安装依赖
    log "INFO" "安装 Python 依赖..."
    pip install -r requirements.txt -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple >> "${LOG_FILE}" 2>&1 || \
    pip install -r requirements.txt >> "${LOG_FILE}" 2>&1

    # 配置 AstrBot
    log "INFO" "配置 AstrBot..."
    if [ ! -f "astrbot.json" ]; then
        if [ -f "astrbot.json.template" ]; then
            cp astrbot.json.template astrbot.json
        else
            cat > astrbot.json << EOF
{
    "port": ${ASTRBOT_PORT},
    "host": "0.0.0.0",
    "log_level": "INFO",
    "dashboard": {
        "enabled": true,
        "port": ${ASTRBOT_PORT},
        "host": "0.0.0.0"
    }
}
EOF
        fi
    fi

    # 创建 systemd 服务
    log "INFO" "创建 systemd 服务..."
    cat > /etc/systemd/system/astrbot.service << EOF
[Unit]
Description=AstrBot Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >> "${LOG_FILE}" 2>&1

    log "INFO" "AstrBot 源码部署完成"
    return 0
}

# ---------- Docker 部署 ----------
install_docker() {
    log "STEP" "开始 Docker 部署 AstrBot..."
    update_status "astrbot" "installing" "正在 Docker 部署 AstrBot..."

    # 检查 Docker
    if ! command -v docker &>/dev/null; then
        log "INFO" "安装 Docker..."
        curl -fsSL https://get.docker.com | bash >> "${LOG_FILE}" 2>&1
        systemctl enable docker >> "${LOG_FILE}" 2>&1
        systemctl start docker >> "${LOG_FILE}" 2>&1
    fi

    # 克隆仓库
    if [ ! -d "${INSTALL_DIR}" ]; then
        log "INFO" "克隆 AstrBot 仓库..."
        mkdir -p "$(dirname "${INSTALL_DIR}")"
        git clone "${GIT_REPO}" "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1
        cd "${INSTALL_DIR}"
    else
        cd "${INSTALL_DIR}"
        log "INFO" "更新 AstrBot 代码..."
        git pull >> "${LOG_FILE}" 2>&1 || true
    fi

    # 修改 docker-compose.yml 端口
    if [ -f "docker-compose.yml" ]; then
        log "INFO" "使用 Docker Compose 部署..."
        ASTRBOT_PORT=${ASTRBOT_PORT} docker compose up -d >> "${LOG_FILE}" 2>&1
    elif [ -f "Dockerfile" ]; then
        log "INFO" "使用 Docker 构建..."
        docker build -t astrbot . >> "${LOG_FILE}" 2>&1
        docker run -d \
            --name astrbot \
            --restart always \
            -p ${ASTRBOT_PORT}:${ASTRBOT_PORT} \
            -v "${INSTALL_DIR}:/app" \
            astrbot >> "${LOG_FILE}" 2>&1
    else
        log "ERROR" "未找到 Docker 配置文件"
        update_status "astrbot" "failed" "未找到 Docker 配置文件"
        return 1
    fi

    log "INFO" "AstrBot Docker 部署完成"
    return 0
}

# ---------- 获取 AstrBot 信息 ----------
get_astrbot_info() {
    log "STEP" "获取 AstrBot 服务信息..."

    local api_key=""
    local public_ip=$(get_public_ip)

    # 尝试从配置文件获取 API Key
    local config_file="${INSTALL_DIR}/astrbot.json"
    if [ -f "${config_file}" ]; then
        api_key=$(python3 -c "
import json
try:
    data = json.load(open('${config_file}'))
    # 尝试从不同路径读取 key
    key = data.get('api_key', '') or data.get('dashboard', {}).get('api_key', '') or data.get('token', '') or ''
    print(key)
except:
    print('')
" 2>/dev/null) || api_key=""
    fi

    # 如果没找到，尝试从环境变量或日志获取
    if [ -z "${api_key}" ]; then
        api_key=$(grep -oP 'api[_-]?key["\s:=]+[\"'"'"']?\K[a-zA-Z0-9_-]+' "${LOG_FILE}" 2>/dev/null | tail -1 || echo "")
    fi

    if [ -z "${api_key}" ]; then
        api_key="请登录 AstrBot Dashboard 查看"
        log "WARN" "未找到 API Key，请登录 Dashboard 查看"
    fi

    log "INFO" "==================================="
    log "INFO" " AstrBot 服务信息"
    log "INFO" "==================================="
    log "INFO" "Dashboard: http://${public_ip}:${ASTRBOT_PORT}"
    log "INFO" "API Key:   ${api_key}"
    log "INFO" "安装目录:  ${INSTALL_DIR}"
    log "INFO" "部署方式:  ${INSTALL_METHOD}"
    log "INFO" "==================================="

    # 保存到服务信息文件
    save_service_info "astrbot" "dashboard_url" "http://${public_ip}:${ASTRBOT_PORT}"
    save_service_info "astrbot" "api_key" "${api_key}"
    save_service_info "astrbot" "install_dir" "${INSTALL_DIR}"
    save_service_info "astrbot" "method" "${INSTALL_METHOD}"

    log "INFO" "服务信息已保存到 ${SERVICE_INFO_FILE}"
}

# ---------- 主流程 ----------
main() {
    parse_args "$@"

    log "STEP" "===== AstrBot 安装/配置 ====="
    log "INFO" "部署方式: ${INSTALL_METHOD}"
    log "INFO" "安装目录: ${INSTALL_DIR}"

    update_status "astrbot" "started" "开始安装 AstrBot (${INSTALL_METHOD})..."

    # 安装
    if [ "${INSTALL_METHOD}" = "docker" ]; then
        install_docker || return 1
    else
        install_source || return 1
    fi

    # 获取信息
    get_astrbot_info

    update_status "astrbot" "completed" "AstrBot 安装完成"

    log "STEP" "===== AstrBot 安装完成 ====="
    return 0
}

# 如果直接执行此脚本，则运行 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi