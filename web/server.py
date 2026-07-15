#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================
# Web 后端 - NapCat/AstrBot/宝塔面板 一键部署工具
# 功能：查看日志、部署进度、显示服务信息
# ============================================================

import os
import json
import subprocess
from flask import Flask, Flask, jsonify, request, send_from_directory, stream_with_context, Response
from flask_cors import CORS
import threading
import time

app = Flask(__name__, static_folder='./static', static_url_path='')
CORS(app)

# 配置文件路径
LOG_FILE = "/tmp/deploy-helper.log"
STATUS_FILE = "/tmp/deploy-status.json"
SERVICE_INFO_FILE = "/tmp/deploy-service-info.json"
CONFIG_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config.json")

# 读取配置
def load_config():
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except:
        return {
            "web": {
                "host": "0.0.0.0",
                "port": 18080
            }
        }

# ========== API 路由 ==========

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/config')
def get_config():
    """获取配置"""
    return jsonify(load_config())

@app.route('/api/logs')
def get_logs():
    """获取所有日志"""
    if not os.path.exists(LOG_FILE):
        return jsonify({"logs": []})
    with open(LOG_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()[-200:]  # 最后 200 行
    return jsonify({"logs": lines})

@app.route('/api/status')
def get_status():
    """获取部署状态"""
    if not os.path.exists(STATUS_FILE):
        return jsonify({})
    with open(STATUS_FILE, 'r', encoding='utf-8') as f:
        try:
            return jsonify(json.load(f))
        except:
            return jsonify({})

@app.route('/api/info')
def get_service_info():
    """获取服务信息"""
    if not os.path.exists(SERVICE_INFO_FILE):
        return jsonify({})
    with open(SERVICE_INFO_FILE, 'r', encoding='utf-8') as f:
        try:
            return jsonify(json.load(f))
        except:
            return jsonify({})

@app.route('/api/tail')
def stream_logs():
    """流式返回实时日志"""
    def generate():
        if not os.path.exists(LOG_FILE):
            yield "data: 日志文件不存在\n\n"
            return
        with open(LOG_FILE, 'r') as f:
            f.seek(0, 2)
            while True:
                line = f.readline()
                if line:
                    yield f"data: {line}\n\n"
                else:
                    time.sleep(0.1)
    return Response(
        stream_with_context(generate()),
        content_type='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
        }
    )

@app.route('/api/deploy', methods=['POST'])
def start_deploy():
    """开始部署"""
    data = request.get_json()

    # 收集参数
    options = []
    napcat_version = data.get('napcat_version', None)
    if napcat_version:
        options.extend(['--napcat', napcat_version])

    astrbot_method = data.get('astrbot_method', None)
    if astrbot_method:
        options.extend(['--astrbot', astrbot_method])

    if data.get('deploy_baota', False):
        options.append('--baota')

    qq_number = data.get('qq_number', '')
    if qq_number:
        options.extend(['--qq', qq_number])

    fix_repo = data.get('fix_repo', '')
    if fix_repo:
        options.extend(['--fix-repo', fix_repo])

    options.append('--web')

    # 清空旧日志
    if os.path.exists(LOG_FILE):
        open(LOG_FILE, 'w').close()

    # 后台执行部署脚本
    main_script = os.path.join(os.path.dirname(os.path.dirname(__file__)), "main.sh")

    def run_deploy():
        cmd = ['bash', main_script] + options
        subprocess.run(cmd, capture_output=False, text=True)

    thread = threading.Thread(target=run_deploy)
    thread.daemon = True
    thread.start()

    return jsonify({
        "status": "started",
        "message": "部署已开始，请查看实时日志"
    })

@app.route('/api/command', methods=['POST'])
def run_command():
    """执行自定义命令（启动服务等）"""
    data = request.get_json()
    cmd = data.get('command', '')
    if not cmd:
        return jsonify({"error": "命令不能为空"}), 400

    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return jsonify({
            "output": result.stdout,
            "error": result.stderr,
            "returncode": result.returncode
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": "命令执行超时"}), 408

@app.route('/api/restart-napcat', methods=['POST'])
def restart_napcat():
    """重启 NapCat"""
    data = request.get_json()
    qq = data.get('qq', '')
    cmd = f"pkill -f 'xvfb-run.*napcat' 2>/dev/null || true; sleep 1; xvfb-run -a /root/Napcat/opt/QQ/qq --no-sandbox -q {qq} &"
    try:
        subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return jsonify({"status": "ok", "message": "NapCat 已重启"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

if __name__ == '__main__':
    config = load_config()
    host = config.get('web', {}).get('host', '0.0.0.0')
    port = config.get('web', {}).get('port', 18080)
    print(f"="*50)
    print(f"Web 管理界面已启动")
    print(f"访问地址: http://{host}:{port}")
    print(f"="*50)
    app.run(host=host, port=port, debug=False, threaded=True)