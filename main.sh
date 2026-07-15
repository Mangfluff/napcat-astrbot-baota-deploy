#!/bin/bash
# ============================================================
# NapCat / AstrBot / 宝塔面板 一键部署工具
# 支持交互式选择，Web 管理界面实时查看进度
# 开源地址: https://github.com/your-username/napcat-astrbot-baota-deploy
# ============================================================

set -e

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${PROJECT_DIR}"

# 加载通用函数
source "${PROJECT_DIR}/scripts/common.sh"

# 显示标题
show_banner() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  NapCat / AstrBot / 宝塔面板 一键部署工具${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo -e "${GREEN}功能:${NC}"
    echo "  - NapCatQQ: QQ 机器人框架（支持原版/修复版）"
    echo "  - AstrBot:  多平台 LLM 聊天机器人框架"
    echo "  - 宝塔面板:  Linux 服务器管理面板"
    echo ""
    echo -e "${YELLOW}提示: 部署前请确保使用 root 用户运行${NC}"
    echo ""
}

# ---------- 交互式菜单 ----------
show_menu() {
    echo -e "${BLUE}请选择需要部署的服务（可多选）:${NC}"
    echo ""

    # 默认选择状态
    local deploy_napcat=false
    local deploy_astrbot=false
    local deploy_baota=false
    local napcat_version="original"
    local astrbot_method="source"
    local qq_number=""
    local fix_repo_url="https://github.com/your-username/napcat-fix"

    # 读取配置文件中的默认值
    napcat_version=$(python3 -c "import json; print(json.load(open('config.json'))['services']['napcat']['default_version'])" 2>/dev/null || echo "original")
    astrbot_method=$(python3 -c "import json; print(json.load(open('config.json'))['services']['astrbot']['default_method'])" 2>/dev/null || echo "source")

    # 交互式选择
    while true; do
        echo "1) NapCatQQ    - QQ 机器人框架"
        echo "2) AstrBot     - LLM 聊天机器人"
        echo "3) 宝塔面板    - 服务器管理面板"
        echo "4) 全部部署"
        echo "0) 开始部署"
        echo ""
        read -p "请输入选项 (0-4, 可以连续输入多选): " choice

        case $choice in
            1)
                deploy_napcat=true
                echo -e "${GREEN}✓ NapCatQQ 已选择${NC}"
                # NapCat 版本选择
                echo ""
                echo "请选择 NapCat 版本:"
                echo "1) 官方原版 (默认)"
                echo "2) 修复版 (Fix)"
                read -p "请输入选项 (1-2): " ver_choice
                if [ "$ver_choice" = "2" ]; then
                    napcat_version="fix"
                    read -p "请输入修复版仓库地址 (默认: ${fix_repo_url}): " custom_repo
                    [ -n "$custom_repo" ] && fix_repo_url="$custom_repo"
                fi
                echo -e "${GREEN}✓ NapCat 版本: ${napcat_version}${NC}"
                ;;
            2)
                deploy_astrbot=true
                echo -e "${GREEN}✓ AstrBot 已选择${NC}"
                echo ""
                echo "请选择部署方式:"
                echo "1) 源码部署 (默认)"
                echo "2) Docker 部署"
                read -p "请输入选项 (1-2): " method_choice
                [ "$method_choice" = "2" ] && astrbot_method="docker"
                echo -e "${GREEN}✓ AstrBot 部署方式: ${astrbot_method}${NC}"
                ;;
            3)
                deploy_baota=true
                echo -e "${GREEN}✓ 宝塔面板 已选择${NC}"
                ;;
            4)
                deploy_napcat=true
                deploy_astrbot=true
                deploy_baota=true
                echo -e "${GREEN}✓ 全部服务已选择${NC}"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入${NC}"
                ;;
        esac
        echo ""
    done

    # 如果选择了 NapCat，询问 QQ 号
    if [ "$deploy_napcat" = true ]; then
        echo ""
        read -p "请输入 QQ 号 (用于 NapCat 登录): " qq_number
        if [ -z "$qq_number" ]; then
            log "WARN" "未输入 QQ 号，后续可手动配置"
        fi
    fi

    # 确认选择
    echo ""
    echo -e "${CYAN}========== 部署确认 ==========${NC}"
    [ "$deploy_napcat" = true ] && echo -e "  NapCatQQ:   ${GREEN}是${NC} (版本: ${napcat_version})" || echo -e "  NapCatQQ:   ${RED}否${NC}"
    [ "$deploy_astrbot" = true ] && echo -e "  AstrBot:    ${GREEN}是${NC} (方式: ${astrbot_method})" || echo -e "  AstrBot:    ${RED}否${NC}"
    [ "$deploy_baota" = true ] && echo -e "  宝塔面板:   ${GREEN}是${NC}" || echo -e "  宝塔面板:   ${RED}否${NC}"
    echo ""

    read -p "确认开始部署? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "INFO" "部署已取消"
        exit 0
    fi

    # 开始部署
    echo ""
    log "STEP" "===== 开始部署 ====="

    # 初始化状态文件
    echo "{}" > "${DEPLOY_STATUS_FILE}"
    echo "{}" > "${SERVICE_INFO_FILE}"

    # 安装系统依赖
    install_deps

    # 部署 NapCat
    if [ "$deploy_napcat" = true ]; then
        echo ""
        log "STEP" ">>>>>> 开始部署 NapCatQQ <<<<<<"
        bash "${PROJECT_DIR}/scripts/install_napcat.sh" \
            --version "${napcat_version}" \
            --qq "${qq_number}" \
            --fix-repo "${fix_repo_url}" \
            || log "ERROR" "NapCatQQ 部署失败"
        echo ""
        log "STEP" "====== NapCatQQ 部署完成 ======"
    fi

    # 部署 AstrBot
    if [ "$deploy_astrbot" = true ]; then
        echo ""
        log "STEP" ">>>>>> 开始部署 AstrBot <<<<<<"
        bash "${PROJECT_DIR}/scripts/install_astrbot.sh" \
            --method "${astrbot_method}" \
            || log "ERROR" "AstrBot 部署失败"
        echo ""
        log "STEP" "====== AstrBot 部署完成 ======"
    fi

    # 部署宝塔面板
    if [ "$deploy_baota" = true ]; then
        echo ""
        log "STEP" ">>>>>> 开始部署宝塔面板 <<<<<<"
        bash "${PROJECT_DIR}/scripts/install_baota.sh" \
            || log "ERROR" "宝塔面板部署失败"
        echo ""
        log "STEP" "====== 宝塔面板部署完成 ======"
    fi

    # 显示汇总信息
    show_summary
}

# ---------- 显示汇总信息 ----------
show_summary() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}           部署完成 - 服务信息汇总${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""

    if [ -f "${SERVICE_INFO_FILE}" ]; then
        python3 -c "
import json
try:
    data = json.load(open('${SERVICE_INFO_FILE}'))
    for service, info in data.items():
        print(f'[{service.upper()}]')
        for key, value in info.items():
            print(f'  {key}: {value}')
        print()
except Exception as e:
    print(f'读取服务信息失败: {e}')
" 2>/dev/null || cat "${SERVICE_INFO_FILE}"
    fi

    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo -e "${GREEN}Web 管理界面已启动!${NC}"
    echo "请访问: http://<服务器IP>:18080"
    echo ""
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
    echo -e "${YELLOW}服务信息: ${SERVICE_INFO_FILE}${NC}"
    echo ""
}

# ---------- 启动 Web 管理界面 ----------
start_web_ui() {
    log "STEP" "启动 Web 管理界面..."

    # 安装 Python 依赖
    log "INFO" "安装 Web 后端依赖..."
    pip install flask flask-cors --break-system-packages >> "${LOG_FILE}" 2>&1 || \
    pip3 install flask flask-cors --break-system-packages >> "${LOG_FILE}" 2>&1 || \
    log "WARN" "Flask 安装失败，请手动安装"

    # 启动后端
    log "INFO" "启动 Web 后端服务..."
    nohup python3 "${PROJECT_DIR}/web/server.py" > /tmp/deploy-web.log 2>&1 &
    local web_pid=$!
    echo "${web_pid}" > /tmp/deploy-web.pid

    sleep 2
    if kill -0 ${web_pid} 2>/dev/null; then
        log "INFO" "Web 管理界面已启动: http://0.0.0.0:18080"
        log "INFO" "请在浏览器中访问 http://<服务器IP>:18080"
    else
        log "ERROR" "Web 管理界面启动失败，请查看日志: /tmp/deploy-web.log"
    fi
}

# ---------- 命令行模式（非交互式） ----------
cli_mode() {
    local deploy_napcat=false
    local deploy_astrbot=false
    local deploy_baota=false
    local napcat_version="original"
    local astrbot_method="source"
    local qq_number=""
    local fix_repo_url="https://github.com/your-username/napcat-fix"
    local start_web=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --napcat) deploy_napcat=true; napcat_version="$2"; shift 2 ;;
            --astrbot) deploy_astrbot=true; astrbot_method="$2"; shift 2 ;;
            --baota) deploy_baota=true; shift ;;
            --qq) qq_number="$2"; shift 2 ;;
            --fix-repo) fix_repo_url="$2"; shift 2 ;;
            --web) start_web=true; shift ;;
            --help)
                echo "用法: bash main.sh [选项]"
                echo "交互模式: 直接运行 bash main.sh"
                echo "命令行模式:"
                echo "  --napcat <original|fix>    部署 NapCatQQ"
                echo "  --astrbot <source|docker>  部署 AstrBot"
                echo "  --baota                    部署宝塔面板"
                echo "  --qq <QQ号>                设置 QQ 号"
                echo "  --fix-repo <url>           修复版仓库地址"
                echo "  --web                      启动 Web 管理界面"
                exit 0
                ;;
            *) echo "未知参数: $1"; exit 1 ;;
        esac
    done

    # 初始化状态文件
    echo "{}" > "${DEPLOY_STATUS_FILE}"
    echo "{}" > "${SERVICE_INFO_FILE}"

    # 安装系统依赖
    install_deps

    # 部署
    if [ "$deploy_napcat" = true ]; then
        bash "${PROJECT_DIR}/scripts/install_napcat.sh" --version "${napcat_version}" --qq "${qq_number}" --fix-repo "${fix_repo_url}"
    fi
    if [ "$deploy_astrbot" = true ]; then
        bash "${PROJECT_DIR}/scripts/install_astrbot.sh" --method "${astrbot_method}"
    fi
    if [ "$deploy_baota" = true ]; then
        bash "${PROJECT_DIR}/scripts/install_baota.sh"
    fi

    show_summary

    if [ "$start_web" = true ]; then
        start_web_ui
    fi
}

# ---------- 主入口 ----------
main() {
    check_root
    check_arch
    show_banner

    # 如果有命令行参数，使用 CLI 模式
    if [ $# -gt 0 ]; then
        cli_mode "$@"
    else
        # 交互模式
        show_menu
        # 部署完成后默认启动 Web 界面
        start_web_ui
    fi
}

main "$@"