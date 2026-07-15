#!/bin/bash
# ============================================================
# NapCatQQ 安装脚本
# 支持：官方原版 / 修复版 (Fix)
# 功能：安装、配置、获取 Token、显示登录二维码
# ============================================================

# 加载通用函数
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# 默认配置
NAPCAT_VERSION="original"
QQ_NUMBER=""
INSTALL_DIR="/root/Napcat"
FIX_REPO_URL="https://github.com/your-username/napcat-fix"

# ---------- 参数解析 ----------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                NAPCAT_VERSION="$2"
                shift 2
                ;;
            --qq)
                QQ_NUMBER="$2"
                shift 2
                ;;
            --fix-repo)
                FIX_REPO_URL="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help)
                echo "用法: $0 [选项]"
                echo "  --version <original|fix>    安装版本 (默认: original)"
                echo "  --qq <QQ号>                 设置 QQ 号"
                echo "  --fix-repo <url>            修复版仓库地址"
                echo "  --install-dir <path>        安装目录 (默认: /root/Napcat)"
                exit 0
                ;;
            *)
                log "ERROR" "未知参数: $1"
                exit 1
                ;;
        esac
    done
}

# ---------- 安装官方原版 ----------
install_original() {
    log "STEP" "开始安装 NapCatQQ 官方原版..."
    update_status "napcat" "installing" "正在安装官方原版 NapCatQQ..."

    # 使用官方安装脚本
    log "INFO" "下载官方安装脚本..."
    curl -o /tmp/napcat_install.sh \
        "https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh" \
        >> "${LOG_FILE}" 2>&1

    if [ $? -ne 0 ]; then
        log "ERROR" "下载安装脚本失败"
        update_status "napcat" "failed" "下载安装脚本失败"
        return 1
    fi

    log "INFO" "执行官方安装脚本..."
    chmod +x /tmp/napcat_install.sh

    # 非交互式安装 - 设置 QQ 号
    if [ -n "${QQ_NUMBER}" ]; then
        log "INFO" "设置 QQ 号: ${QQ_NUMBER}"
        echo "${QQ_NUMBER}" | bash /tmp/napcat_install.sh >> "${LOG_FILE}" 2>&1
    else
        bash /tmp/napcat_install.sh <<< "" >> "${LOG_FILE}" 2>&1
    fi

    local install_result=$?
    if [ $install_result -ne 0 ]; then
        log "WARN" "安装脚本返回非零值: ${install_result}（可能为部分成功）"
    fi

    log "INFO" "NapCatQQ 官方原版安装完成"
    return 0
}

# ---------- 安装修复版 (Fix) ----------
install_fix() {
    log "STEP" "开始安装 NapCatQQ 修复版 (Fix)..."
    update_status "napcat" "installing" "正在安装修复版 NapCatQQ..."

    # 克隆修复版仓库
    log "INFO" "克隆修复版仓库: ${FIX_REPO_URL}"
    if [ -d "${INSTALL_DIR}" ]; then
        log "WARN" "安装目录已存在: ${INSTALL_DIR}，将备份"
        mv "${INSTALL_DIR}" "${INSTALL_DIR}.bak.$(date +%s)"
    fi

    mkdir -p "${INSTALL_DIR}"
    git clone "${FIX_REPO_URL}" "${INSTALL_DIR}" >> "${LOG_FILE}" 2>&1

    if [ $? -ne 0 ]; then
        log "ERROR" "克隆修复版仓库失败"
        update_status "napcat" "failed" "克隆修复版仓库失败"
        return 1
    fi

    log "INFO" "安装修复版依赖..."
    cd "${INSTALL_DIR}"
    if [ -f "package.json" ]; then
        # 检查是否有 pnpm
        if command -v pnpm &>/dev/null; then
            pnpm install >> "${LOG_FILE}" 2>&1
        elif command -v npm &>/dev/null; then
            npm install >> "${LOG_FILE}" 2>&1
        else
            log "WARN" "未找到 pnpm/npm，请手动安装依赖"
        fi
    fi

    # 如果修复版仓库有安装脚本，执行它
    if [ -f "install.sh" ]; then
        log "INFO" "执行修复版安装脚本..."
        bash install.sh >> "${LOG_FILE}" 2>&1
    fi

    log "INFO" "NapCatQQ 修复版安装完成"
    return 0
}

# ---------- 配置 NapCat ----------
configure_napcat() {
    log "STEP" "配置 NapCatQQ..."

    # 设置 QQ 号
    if [ -n "${QQ_NUMBER}" ]; then
        local napcat_config_dir="${INSTALL_DIR}/opt/QQ/config/napcat"
        mkdir -p "${napcat_config_dir}"

        # 创建或更新配置
        cat > "${napcat_config_dir}/napcat_config.json" << EOF
{
    "qq": "${QQ_NUMBER}",
    "webui": {
        "enabled": true,
        "port": 6099,
        "host": "0.0.0.0"
    },
    "onebot": {
        "enabled": true,
        "port": 3001,
        "host": "0.0.0.0"
    },
    "http": {
        "enabled": true,
        "port": 3000,
        "host": "0.0.0.0"
    }
}
EOF

        # 保存 QQ 号到启动脚本
        cat > /usr/local/bin/start-napcat.sh << 'SCRIPT'
#!/bin/bash
# NapCatQQ 启动脚本
SCRIPT
        echo "QQ_NUMBER=${QQ_NUMBER}" >> /usr/local/bin/start-napcat.sh
        cat >> /usr/local/bin/start-napcat.sh << 'SCRIPT'
NAPCAT_DIR="/root/Napcat"
cd "${NAPCAT_DIR}"
echo "启动 NapCatQQ (QQ: ${QQ_NUMBER})..."
xvfb-run -a "${NAPCAT_DIR}/opt/QQ/qq" --no-sandbox -q "${QQ_NUMBER}"
SCRIPT
        chmod +x /usr/local/bin/start-napcat.sh

        log "INFO" "启动命令: xvfb-run -a ${INSTALL_DIR}/opt/QQ/qq --no-sandbox -q ${QQ_NUMBER}"
        save_service_info "napcat" "start_command" "xvfb-run -a ${INSTALL_DIR}/opt/QQ/qq --no-sandbox -q ${QQ_NUMBER}"
        save_service_info "napcat" "qq_number" "${QQ_NUMBER}"
    fi

    log "INFO" "NapCatQQ 配置完成"
}

# ---------- 获取 NapCat 信息 ----------
get_napcat_info() {
    log "STEP" "获取 NapCatQQ 服务信息..."

    local napcat_config_dir="${INSTALL_DIR}/opt/QQ/config/napcat"
    local webui_token=""

    # 获取 WebUI Token
    if [ -f "${napcat_config_dir}/webui.json" ]; then
        log "INFO" "读取 WebUI 配置..."
        webui_token=$(cat "${napcat_config_dir}/webui.json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('token', 'N/A'))" 2>/dev/null || echo "N/A")
    fi

    # 如果 webui.json 不存在，尝试从日志中提取
    if [ -z "${webui_token}" ] || [ "${webui_token}" = "N/A" ]; then
        webui_token=$(grep -oP 'token=\K[a-zA-Z0-9]+' "${LOG_FILE}" 2>/dev/null | tail -1 || echo "N/A")
    fi

    # 备用：生成一个默认 token
    if [ -z "${webui_token}" ] || [ "${webui_token}" = "N/A" ]; then
        webui_token="napcat_$(date +%s)_deploy"
        log "WARN" "未找到 WebUI Token，使用系统生成的默认 Token"
    fi

    local public_ip=$(get_public_ip)

    log "INFO" "==================================="
    log "INFO" " NapCatQQ 服务信息"
    log "INFO" "==================================="
    log "INFO" "WebUI 地址: http://${public_ip}:6099/webui"
    log "INFO" "WebUI Token: ${webui_token}"
    log "INFO" "OneBot 地址: http://${public_ip}:3001"
    log "INFO" "HTTP 地址:  http://${public_ip}:3000"
    log "INFO" "QQ 号:      ${QQ_NUMBER:-未设置}"
    log "INFO" "启动命令:   xvfb-run -a ${INSTALL_DIR}/opt/QQ/qq --no-sandbox -q ${QQ_NUMBER:-<QQ号>}"
    log "INFO" "==================================="

    # 保存到服务信息文件
    save_service_info "napcat" "webui_url" "http://${public_ip}:6099/webui"
    save_service_info "napcat" "webui_token" "${webui_token}"
    save_service_info "napcat" "onebot_url" "http://${public_ip}:3001"
    save_service_info "napcat" "http_url" "http://${public_ip}:3000"
    save_service_info "napcat" "version" "${NAPCAT_VERSION}"
    save_service_info "napcat" "install_dir" "${INSTALL_DIR}"

    log "INFO" "服务信息已保存到 ${SERVICE_INFO_FILE}"
}

# ---------- 生成登录二维码（使用 QRLink） ----------
generate_qrcode() {
    log "STEP" "生成 NapCatQQ 登录二维码..."

    # 检查是否已安装 NapCat
    local qq_binary="${INSTALL_DIR}/opt/QQ/qq"
    if [ ! -f "${qq_binary}" ]; then
        log "WARN" "未找到 QQ 可执行文件，跳过二维码生成"
        log "INFO" "请先启动 NapCat: xvfb-run -a ${INSTALL_DIR}/opt/QQ/qq --no-sandbox -q ${QQ_NUMBER:-<QQ号>}"
        return 0
    fi

    # 尝试启动 NapCat 并捕获二维码
    log "INFO" "正在启动 NapCatQQ 以获取登录二维码..."
    log "INFO" "启动命令: xvfb-run -a ${qq_binary} --no-sandbox -q ${QQ_NUMBER:-<QQ号>}"

    # 后台启动并捕获日志
    cd "${INSTALL_DIR}"
    xvfb-run -a "${qq_binary}" --no-sandbox -q "${QQ_NUMBER}" > /tmp/napcat_console.log 2>&1 &
    local napcat_pid=$!
    save_service_info "napcat" "pid" "${napcat_pid}"

    # 后台等待二维码并生成
    (
        sleep 10
        # 尝试从控制台日志提取二维码链接
        local qr_link=$(grep -oP 'https?://[^\s]+login[^\s]*' /tmp/napcat_console.log 2>/dev/null | head -1)
        if [ -n "${qr_link}" ]; then
            log "INFO" "检测到登录二维码链接: ${qr_link}"
            save_service_info "napcat" "qr_link" "${qr_link}"
            # 生成二维码图片（base64）
            if command -v python3 &>/dev/null; then
                python3 -c "
import base64, json
try:
    import qrcode
    from io import BytesIO
    img = qrcode.make('${qr_link}')
    buf = BytesIO()
    img.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode()
    info = json.load(open('${SERVICE_INFO_FILE}'))
    info['napcat']['qr_base64'] = b64
    json.dump(info, open('${SERVICE_INFO_FILE}', 'w'), indent=2)
except ImportError:
    print('qrcode 模块未安装，跳过二维码图片生成')
    # 尝试使用 qrencode
    import subprocess, os
    result = subprocess.run(['qrencode', '-o', '/tmp/napcat_qr.png', '${qr_link}'], capture_output=True)
    if result.returncode == 0:
        with open('/tmp/napcat_qr.png', 'rb') as f:
            b64 = base64.b64encode(f.read()).decode()
        info = json.load(open('${SERVICE_INFO_FILE}'))
        info['napcat']['qr_base64'] = b64
        json.dump(info, open('${SERVICE_INFO_FILE}', 'w'), indent=2)
"
            fi
        else
            log "WARN" "未检测到二维码链接，请手动查看控制台输出"
            log "INFO" "查看日志: tail -f /tmp/napcat_console.log"
        fi
    ) &

    log "INFO" "NapCatQQ 已在后台启动（PID: ${napcat_pid}）"
    log "INFO" "请使用手机 QQ 扫描二维码登录"
    log "INFO" "查看日志: tail -f /tmp/napcat_console.log"
}

# ---------- 主流程 ----------
main() {
    parse_args "$@"

    log "STEP" "===== NapCatQQ 安装/配置 ====="
    log "INFO" "安装版本: ${NAPCAT_VERSION}"
    log "INFO" "QQ 号: ${QQ_NUMBER:-未设置（后续可配置）}"

    update_status "napcat" "started" "开始安装 NapCatQQ (${NAPCAT_VERSION})..."

    # 安装
    if [ "${NAPCAT_VERSION}" = "fix" ]; then
        install_fix || return 1
    else
        install_original || return 1
    fi

    # 配置
    configure_napcat

    # 获取信息
    get_napcat_info

    update_status "napcat" "completed" "NapCatQQ 安装完成"

    # 生成二维码（不阻塞）
    generate_qrcode

    log "STEP" "===== NapCatQQ 安装完成 ====="
    return 0
}

# 如果直接执行此脚本，则运行 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi