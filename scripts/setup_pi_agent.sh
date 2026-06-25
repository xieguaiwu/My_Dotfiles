#!/bin/bash
# Install pi-agent (coding agent CLI) on Fedora / Kali / Debian
set -e

# 检测系统
detect_distro() {
    if [ -f /etc/fedora-release ]; then echo "fedora"
    elif grep -qi "kali" /etc/os-release 2>/dev/null; then echo "kali"
    elif [ -f /etc/debian_version ]; then echo "debian"
    else echo "unknown"; fi
}

DISTRO=$(detect_distro)

echo ">>> 检测到 $DISTRO 系统"

# 确保 Node.js 和 npm 已安装
if ! command -v node &>/dev/null; then
    echo ">>> 安装 Node.js..."
    case "$DISTRO" in
        fedora) sudo dnf install -y nodejs npm ;;
        *) sudo apt install -y nodejs npm ;;
    esac
fi

# 配置 npm 全局安装路径（避免 sudo 权限问题）
NPM_PREFIX="${HOME}/.npm-global"
mkdir -p "$NPM_PREFIX"
npm config set prefix "$NPM_PREFIX" 2>/dev/null || true

# 确保 PATH 中包含 npm 全局 bin
export PATH="$NPM_PREFIX/bin:$PATH"
if ! grep -q "npm-global" ~/.config/fish/config.fish 2>/dev/null; then
    mkdir -p ~/.config/fish
    echo 'set -gx PATH $HOME/.npm-global/bin $PATH' >> ~/.config/fish/config.fish
fi
if ! grep -q "npm-global" ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi

echo ">>> 安装 pi-agent (npm: @earendil-works/pi-coding-agent)..."
npm install -g @earendil-works/pi-coding-agent@latest

echo ">>> 验证安装..."
pi --version 2>/dev/null || echo "请重新打开终端后测试：pi --version"

echo ">>> pi-agent 安装完成！"
echo "运行 'pi' 启动交互模式，或 'pi \"你的问题\"' 直接提问。"
