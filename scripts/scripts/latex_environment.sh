#!/bin/bash
# LaTeX 环境设置脚本 for Fedora 系统

set -e

echo "=== 检查并安装 LaTeX 环境 ==="

# 1. 检查并安装 texlive (pdflatex)
if ! command -v pdflatex &> /dev/null; then
    echo "pdflatex 未找到，正在安装 texlive..."
    sudo dnf install -y texlive texlive-collection-langenglish texlive-collection-langchinese texlive-microtype
    echo "texlive 安装完成"
else
    echo "pdflatex 已安装"
    # 检查是否需要安装中文语言包
    if ! rpm -q texlive-collection-langchinese &> /dev/null; then
        echo "正在安装 texlive 中文语言包..."
        sudo dnf install -y texlive-collection-langchinese
        echo "中文语言包安装完成"
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
    sudo dnf install -y texlive-pdftex
    echo "pdftex 安装完成"
else
    echo "pdftex 已安装"
fi

echo "=== LaTeX 环境设置完成 ==="
