// ========== 全局变量 ==========
let eventSource = null;

// ========== DOM 元素 ==========
const deployNapcatCheck = document.getElementById('deploy_napcat');
const napcatOptions = document.getElementById('napcat-options');
const fixRepoField = document.getElementById('fix-repo-field');
const startDeployBtn = document.getElementById('start-deploy');
const refreshInfoBtn = document.getElementById('refresh-info');
const logContainer = document.getElementById('log-container');
const statusGrid = document.getElementById('status-grid');
const napcatInfoBlock = document.getElementById('napcat-info');
const astrbotInfoBlock = document.getElementById('astrbot-info');
const baotaInfoBlock = document.getElementById('baota-info');
const qrcodeImg = document.getElementById('qrcode-img');

// ========== 事件监听 ==========

// NapCat 版本选择显示/隐藏修复版仓库
document.querySelectorAll('input[name="napcat_version"]').forEach(radio => {
    radio.addEventListener('change', () => {
        if (radio.value === 'fix') {
            fixRepoField.style.display = 'block';
        } else {
            fixRepoField.style.display = 'none';
        }
    });
});

// NapCat 是否部署显示/隐藏选项
deployNapcatCheck.addEventListener('change', () => {
    if (deployNapcatCheck.checked) {
        napcatOptions.style.display = 'block';
    } else {
        napcatOptions.style.display = 'none';
    }
});

// 开始部署
startDeployBtn.addEventListener('click', startDeploy);

// 刷新信息
refreshInfoBtn.addEventListener('click', () => {
    fetchStatus();
    fetchServiceInfo();
});

// ========== 初始化 ==========
window.addEventListener('load', () => {
    connectLogStream();
    fetchConfig();
    fetchStatus();
    fetchServiceInfo();

    // 初始显示
    if (!deployNapcatCheck.checked) {
        napcatOptions.style.display = 'none';
    }
});

// ========== 函数 ==========

// 连接日志流
function connectLogStream() {
    if (eventSource) {
        eventSource.close();
    }
    eventSource = new EventSource('/api/tail');
    eventSource.onmessage = (event) => {
        appendLog(event.data);
        scrollLogToBottom();
    };
    eventSource.onerror = () => {
        console.warn('日志连接断开，将在 5 秒后重连...');
        setTimeout(connectLogStream, 5000);
    };
}

// 添加日志行
function appendLog(line) {
    const div = document.createElement('div');
    div.className = 'line';

    // 根据前缀判断级别
    if (line.includes('[INFO]')) div.classList.add('info');
    else if (line.includes('[STEP]')) div.classList.add('step');
    else if (line.includes('[WARN]')) div.classList.add('warn');
    else if (line.includes('[ERROR]')) div.classList.add('error');

    div.textContent = line;
    logContainer.appendChild(div);
}

// 滚动到底部
function scrollLogToBottom() {
    logContainer.scrollTop = logContainer.scrollHeight;
}

// 获取配置
async function fetchConfig() {
    try {
        const res = await fetch('/api/config');
        const config = await res.json();
        console.log('配置加载完成', config);
    } catch (e) {
        console.error('获取配置失败', e);
    }
}

// 获取部署状态
async function fetchStatus() {
    try {
        const res = await fetch('/api/status');
        const status = await res.json();
        renderStatus(status);
    } catch (e) {
        console.error('获取状态失败', e);
    }
}

// 渲染状态
function renderStatus(status) {
    statusGrid.innerHTML = '';
    for (const [service, data] of Object.entries(status)) {
        const card = document.createElement('div');
        card.className = 'status-card';
        card.innerHTML = `
            <h4>${getServiceName(service)}</h4>
            <span class="status-badge ${data.status}">${getStatusText(data.status)}</span>
            <p style="margin-top: 10px; color: #666;">${data.message}</p>
        `;
        statusGrid.appendChild(card);
    }
}

function getServiceName(service) {
    const names = {
        napcat: 'NapCatQQ',
        astrbot: 'AstrBot',
        baota: '宝塔面板'
    };
    return names[service] || service;
}

function getStatusText(status) {
    const texts = {
        started: '已开始',
        installing: '安装中',
        completed: '已完成',
        failed: '失败'
    };
    return texts[status] || status;
}

// 获取服务信息
async function fetchServiceInfo() {
    try {
        const res = await fetch('/api/info');
        const info = await res.json();
        renderServiceInfo(info);
    } catch (e) {
        console.error('获取服务信息失败', e);
    }
}

// 渲染服务信息
function renderServiceInfo(info) {
    // NapCat 信息
    if (info.napcat) {
        napcatInfoBlock.style.display = 'block';
        const content = napcatInfoBlock.querySelector('.info-content');
        content.innerHTML = '';

        const items = [
            { label: 'WebUI 地址', key: 'webui_url', copy: true },
            { label: 'WebUI Token', key: 'webui_token', copy: true },
            { label: 'OneBot 地址', key: 'onebot_url', copy: false },
            { label: 'QQ 号', key: 'qq_number', copy: false },
            { label: '版本', key: 'version', copy: false },
            { label: '安装目录', key: 'install_dir', copy: false },
            { label: '启动命令', key: 'start_command', copy: true }
        ];

        items.forEach(item => {
            if (info.napcat[item.key] !== undefined) {
                content.appendChild(createInfoItem(item.label, info.napcat[item.key], item.copy));
            }
        });

        // 显示二维码
        if (info.napcat.qr_base64) {
            qrcodeImg.innerHTML = `<img src="data:image/png;base64,${info.napcat.qr_base64}" alt="登录二维码">`;
        } else if (info.napcat.qr_link) {
            // 如果只有链接，没有图片，可以用浏览器生成
            qrcodeImg.innerHTML = `<p><a href="${info.napcat.qr_link}" target="_blank">打开二维码链接</a></p>`;
        } else {
            qrcodeImg.innerHTML = '<p>请启动 NapCat 后获取二维码</p>';
        }
    } else {
        napcatInfoBlock.style.display = 'none';
    }

    // AstrBot 信息
    if (info.astrbot) {
        astrbotInfoBlock.style.display = 'block';
        const content = astrbotInfoBlock.querySelector('.info-content');
        content.innerHTML = '';

        const items = [
            { label: '面板地址', key: 'dashboard_url', copy: true },
            { label: 'API Key', key: 'api_key', copy: true },
            { label: '部署方式', key: 'method', copy: false },
            { label: '安装目录', key: 'install_dir', copy: false }
        ];

        items.forEach(item => {
            if (info.astrbot[item.key] !== undefined) {
                content.appendChild(createInfoItem(item.label, info.astrbot[item.key], item.copy));
            }
        });
    } else {
        astrbotInfoBlock.style.display = 'none';
    }

    // 宝塔信息
    if (info.baota) {
        baotaInfoBlock.style.display = 'block';
        const content = baotaInfoBlock.querySelector('.info-content');
        content.innerHTML = '';

        const items = [
            { label: '面板地址', key: 'panel_url', copy: true },
            { label: '用户名', key: 'username', copy: true },
            { label: '密码', key: 'password', copy: true },
            { label: '端口', key: 'port', copy: false }
        ];

        items.forEach(item => {
            if (info.baota[item.key] !== undefined) {
                content.appendChild(createInfoItem(item.label, info.baota[item.key], item.copy));
            }
        });
    } else {
        baotaInfoBlock.style.display = 'none';
    }
}

// 创建信息项
function createInfoItem(label, value, canCopy) {
    const div = document.createElement('div');
    div.className = 'info-item';
    div.innerHTML = `<label>${label}:</label><span class="value">${value}</span>`;

    if (canCopy) {
        const btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.textContent = '复制';
        btn.onclick = () => {
            navigator.clipboard.writeText(value).then(() => {
                btn.textContent = '已复制';
                setTimeout(() => btn.textContent = '复制', 2000);
            });
        };
        div.appendChild(btn);
    }

    return div;
}

// 开始部署
async function startDeploy() {
    const data = {
        deploy_napcat: document.getElementById('deploy_napcat').checked,
        deploy_astrbot: document.getElementById('deploy_astrbot').checked,
        deploy_baota: document.getElementById('deploy_baota').checked,
    };

    if (data.deploy_napcat) {
        data.napcat_version = document.querySelector('input[name="napcat_version"]:checked').value;
        data.qq_number = document.getElementById('qq_number').value.trim();
        if (data.napcat_version === 'fix') {
            data.fix_repo = document.getElementById('fix_repo').value.trim();
        }
    }

    if (data.deploy_astrbot) {
        data.astrbot_method = document.querySelector('input[name="astrbot_method"]:checked').value;
    }

    // 检查是否选择了至少一个服务
    if (!data.deploy_napcat && !data.deploy_astrbot && !data.deploy_baota) {
        alert('请至少选择一个服务进行部署');
        return;
    }

    startDeployBtn.disabled = true;
    startDeployBtn.textContent = '⏳ 部署中...';

    // 清空日志容器
    logContainer.innerHTML = '';

    try {
        const res = await fetch('/api/deploy', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        console.log('部署已开始', result);
    } catch (e) {
        console.error('启动部署失败', e);
        alert('启动部署失败: ' + e.message);
        startDeployBtn.disabled = false;
        startDeployBtn.textContent = '🚀 开始部署';
    }

    // 轮询状态
    const checkInterval = setInterval(() => {
        fetchStatus();
        fetchServiceInfo();
    }, 3000);

    setTimeout(() => {
        clearInterval(checkInterval);
        startDeployBtn.disabled = false;
        startDeployBtn.textContent = '🚀 开始部署';
    }, 60 * 10 * 1000); // 10 分钟后恢复按钮
}

// 复制到剪贴板
function copyToClipboard(text) {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(text);
    } else {
        const ta = document.createElement('textarea');
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
    }
}