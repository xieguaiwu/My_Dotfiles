#!/bin/bash
# LaTeX 环境设置脚本 for Fedora / Kali Linux / Debian 系统

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

echo "=== 检查并安装 LaTeX 环境 ==="

# 1. 检查并安装 texlive (pdflatex)
if ! command -v pdflatex &> /dev/null; then
    echo "pdflatex 未找到，正在安装 texlive..."
    if [ "$DISTRO" = "fedora" ]; then
        sudo dnf install -y texlive texlive-collection-langenglish texlive-collection-langchinese texlive-microtype
        sudo dnf install -y texlive-standalone texlive-dvipng texlive-preview texlive-dvisvgm
    else
        # Kali 和 Debian 使用相同的 texlive 包名
        sudo apt update
        sudo apt install -y texlive-latex-base texlive-lang-english texlive-lang-chinese texlive-extra-utils
    fi
    echo "texlive 安装完成"
else
    echo "pdflatex 已安装"
    # 检查是否需要安装中文语言包
    if [ "$DISTRO" = "fedora" ]; then
        if ! rpm -q texlive-collection-langchinese &> /dev/null; then
            echo "正在安装 texlive 中文语言包..."
            sudo dnf install -y texlive-collection-langchinese
            echo "中文语言包安装完成"
        fi
    else
        if ! dpkg -l | grep -q texlive-lang-chinese; then
            echo "正在安装 texlive 中文语言包..."
            sudo apt update
            sudo apt install -y texlive-lang-chinese
            echo "中文语言包安装完成"
        fi
    fi
fi

# 2. 检查并安装 tectonic
if ! command -v tectonic &> /dev/null; then
    echo "tectonic 未找到，正在安装..."
    mkdir -p ~/Downloads
    cd ~/Downloads
    wget "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.15.0/tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz"
    gunzip ./tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz
    tar -xf tectonic-0.15.0-x86_64-unknown-linux-gnu.tar
    mkdir -p ~/tectonic
    mv ./tectonic ~/tectonic
    mkdir -p ~/.local/bin
    ln -sf ~/tectonic/tectonic ~/.local/bin/tectonic
    echo "tectonic 安装完成"
else
    echo "tectonic 已安装"
fi

# 3. 检查 pdftex (通常随 texlive 一起安装)
if ! command -v pdftex &> /dev/null; then
    echo "pdftex 未找到，正在安装..."
    if [ "$DISTRO" = "fedora" ]; then
        sudo dnf install -y texlive-pdftex
    else
        sudo apt update
        sudo apt install -y texlive-pdftex
    fi
    echo "pdftex 安装完成"
else
    echo "pdftex 已安装"
fi

echo "=== LaTeX 环境设置完成 ==="
