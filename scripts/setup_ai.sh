#!/bin/bash
# Fedora / Kali Linux / Debian AI 工具安装脚本

set -e

# 检测系统类型
detect_distro() {
    if [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/kali-release ] || grep -qi "kali" /etc/os-release 2>/dev/null; then
        echo "kali"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

case "$DISTRO" in
    fedora)
        echo ">>> 检测到 Fedora 系统"
        ;;
    kali)
        echo ">>> 检测到 Kali Linux 系统"
        ;;
    debian)
        echo ">>> 检测到 Debian 系统"
        ;;
    *)
        echo "错误: 不支持的发行版"
        exit 1
        ;;
esac

echo ">>> 检查并安装 Node.js 和 npm..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y nodejs npm
else
    # Kali 和 Debian 使用相同的包名
    sudo apt install -y nodejs npm
fi

echo ">>> 更新 npm..."
npm install -g npm@latest

echo ">>> 安装 iFlow CLI..."
sudo npm install -g @iflow-ai/iflow-cli

echo ">>> 安装 OpenCode 及其插件..."
sudo npm install -g opencode-ai@latest
sudo npm install -g oh-my-opencode@latest

# OpenCode 插件
sudo npm install -g opencode-browser
sudo npm install -g opencode-pty
sudo npm install -g opencode-wakatime
sudo npm install -g opencode-websearch-cited
sudo npm install -g opencode-worktree
sudo npm install -g @tarquinen/opencode-dcp

echo ">>> 安装 OpenCLI 工具..."
sudo npm install -g @jackwener/opencli

echo ">>> 安装 MCP (Model Context Protocol) 服务器..."
sudo npm install -g @modelcontextprotocol/server-memory
sudo npm install -g @modelcontextprotocol/server-sequential-thinking

echo ">>> 安装其他 AI 辅助工具..."
sudo npm install -g @steipete/oracle
sudo npm install -g clawhub
sudo npm install -g mcporter
sudo npm install -g oh-my-openagent

echo ">>> 安装 Playwright (浏览器自动化)..."
sudo npm install -g playwright
npx playwright install chromium

echo ">>> 安装 AI Agent Skills..."
# 安装 opencli 相关的 skills (支持 iflow-cli, opencode 等多个 agent)
# 使用 --all 参数安装到所有支持的 agent，-y 跳过确认
npx skills add jackwener/opencli -g --all -y

# 安装 find-skills (来自 vercel-labs/skills)
npx skills add vercel-labs/skills -g --skill find-skills --all -y

# 安装 caveman (token 压缩模式)
npx skills add JuliusBrussee/caveman -g --all -y

echo ">>> 已安装的 Skills 列表:"
npx skills list -g

echo ">>> 验证安装..."
echo "--- iFlow CLI ---"
iflow --version 2>/dev/null || echo "iflow 安装失败"

echo "--- OpenCode ---"
opencode --version 2>/dev/null || echo "opencode 安装失败"

echo "--- 全局 npm 包列表 ---"
npm list -g --depth=0

echo ">>> AI 工具安装完成! 🚀"
echo "提示：运行 'iflow' 启动 iFlow CLI"
echo "提示：运行 'opencode' 启动 OpenCode"
echo "提示：已安装的 skills 将自动加载到支持的 agent 中"
