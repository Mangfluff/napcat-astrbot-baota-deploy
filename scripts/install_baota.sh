#!/bin/bash
# ============================================================
# 宝塔面板 安装脚本
# 功能：安装、获取面板信息（地址、用户名、密码）
# ============================================================

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 默认配置
BAOTA_PORT=8888
BAOTA_INSTALL_URL="https://download.bt.cn/install/install-ubuntu_6.0.sh"

# ---------- 参数解析 ----------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port)
                BAOTA_PORT="$2"
                shift 2
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo "  --port <port>    面板端口 (默认: 8888)"
                exit 0
                ;;
            *)
                log "ERROR" "未知参数: $1"
                exit 1
                ;;
        esac
    done
}

# ---------- 安装宝塔面板 ----------
install_baota() {
    log "STEP" "开始安装 宝塔面板..."
    update_status "baota" "installing" "正在安装宝塔面板..."

    # 检测系统
    log "INFO" "检测系统类型..."
    local os_type=""
    if [ -f /etc/os-release ]; then
        os_type=$(grep -oP '^ID=\K.*' /etc/os-release | tr -d '"')
    fi

    # 根据系统选择安装脚本
    local install_url="${BAOTA_INSTALL_URL}"
    if [[ "${os_type}" == "centos" ]] || [[ "${os_type}" == "rhel" ]] || [[ "${os_type}" == "fedora" ]]; then
        install_url="https://download.bt.cn/install/install_6.0.sh"
        log "INFO" "检测到 CentOS/RHEL 系统，使用对应安装脚本"
    else
        log "INFO" "检测到 Ubuntu/Debian 系统，使用对应安装脚本"
    fi

    # 下载安装脚本
    log "INFO" "下载宝塔安装脚本..."
    cd /tmp
    if [ -f "install_baota.sh" ]; then
        rm -f install_baota.sh
    fi

    wget -O install_baota.sh "${install_url}" >> "${LOG_FILE}" 2>&1
    if [ $? -ne 0 ]; then
        log "ERROR" "下载安装脚本失败"
        update_status "baota" "failed" "下载安装脚本失败"
        return 1
    fi

    # 执行安装（非交互式）
    log "INFO" "执行宝塔面板安装（这将需要几分钟）..."
    log "WARN" "安装过程中请勿关闭终端..."

    # 默认安装（自动选择 y）
    echo "y" | bash install_baota.sh >> "${LOG_FILE}" 2>&1

    local install_result=$?
    if [ $install_result -ne 0 ]; then
        log "WARN" "安装脚本返回非零值: ${install_result}"
    fi

    log "INFO" "宝塔面板安装完成"
    return 0
}

# ---------- 获取宝塔面板信息 ----------
get_baota_info() {
    log "STEP" "获取宝塔面板服务信息..."

    local public_ip=$(get_public_ip)
    local panel_url="http://${public_ip}:${BAOTA_PORT}"
    local username=""
    local password=""
    local panel_path=""

    # 宝塔面板默认信息文件
    local bt_default_file="/www/server/panel/data/default.db"
    local bt_config_file="/www/server/panel/config.json"

    # 尝试从 bt 命令获取信息
    log "INFO" "从面板配置获取信息..."

    # 检查 bt 命令
    if command -v bt &>/dev/null; then
        log "INFO" "检测到 bt 命令，获取面板信息..."
        # 获取面板入口地址
        panel_path=$(bt 14 2>/dev/null | grep -oP 'http://[^\s]+' | head -1 || echo "")
        # 获取默认用户名密码
        local bt_info=$(bt 5 2>/dev/null)
        username=$(echo "${bt_info}" | grep -i "username" | grep -oP '[a-zA-Z0-9]+$' | head -1 || echo "")
        password=$(echo "${bt_info}" | grep -i "password" | grep -oP '[a-zA-Z0-9!@#$%^&*()_+{}:<>?]+$' | head -1 || echo "")
    fi

    # 从默认数据库获取
    if [ -z "${username}" ] || [ -z "${password}" ]; then
        if [ -f "${bt_default_file}" ]; then
            log "INFO" "从默认数据库读取信息..."
            local db_info=$(python3 -c "
import sqlite3, json
try:
    conn = sqlite3.connect('${bt_default_file}')
    c = conn.cursor()
    c.execute('SELECT username, password FROM users LIMIT 1')
    row = c.fetchone()
    if row:
        print(json.dumps({'username': row[0], 'password': row[1]}))
    conn.close()
except:
    print('{}')
" 2>/dev/null) || db_info="{}"

            if [ -n "${db_info}" ] && [ "${db_info}" != "{}" ]; then
                local extracted_username=$(echo "${db_info}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('username', ''))" 2>/dev/null)
                local extracted_password=$(echo "${db_info}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('password', ''))" 2>/dev/null)
                [ -n "${extracted_username}" ] && username="${extracted_username}"
                [ -n "${extracted_password}" ] && password="${extracted_password}"
            fi
        fi
    fi

    # 尝试从安装日志获取
    if [ -z "${username}" ] || [ -z "${password}" ]; then
        log "INFO" "从安装日志提取信息..."
        username=$(grep -i "username" "${LOG_FILE}" | grep -oP '[a-zA-Z0-9]+$' | tail -1 || echo "admin")
        password=$(grep -i "password" "${LOG_FILE}" | grep -oP '[a-zA-Z0-9!@#$%^&*()_+{}:<>?]+$' | tail -1 || echo "请查看面板显示")
    fi

    # 获取面板入口
    if [ -z "${panel_path}" ]; then
        panel_path="${panel_url}/login"
    fi

    log "INFO" "==================================="
    log "INFO" " 宝塔面板服务信息"
    log "INFO" "==================================="
    log "INFO" "面板地址: ${panel_path}"
    log "INFO" "用户名:   ${username:-admin}"
    log "INFO" "密码:     ${password:-请查看终端输出}"
    log "INFO" "端口:     ${BAOTA_PORT}"
    log "INFO" "==================================="
    log "WARN" "首次登录请使用面板显示的账号密码"
    log "WARN" "如果忘记密码，请执行: bt 5"

    # 保存到服务信息文件
    save_service_info "baota" "panel_url" "${panel_path}"
    save_service_info "baota" "username" "${username:-admin}"
    save_service_info "baota" "password" "${password:-请查看终端输出}"
    save_service_info "baota" "port" "${BAOTA_PORT}"

    log "INFO" "服务信息已保存到 ${SERVICE_INFO_FILE}"
}

# ---------- 主流程 ----------
main() {
    parse_args "$@"

    log "STEP" "===== 宝塔面板 安装/配置 ====="

    update_status "baota" "started" "开始安装宝塔面板..."

    # 安装
    install_baota || return 1

    # 等待端口
    wait_for_port "${BAOTA_PORT}" 120

    # 获取信息
    get_baota_info

    update_status "baota" "completed" "宝塔面板安装完成"

    log "STEP" "===== 宝塔面板安装完成 ====="
    return 0
}

# 如果直接执行此脚本，则运行 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi