#!/bin/bash
# Fedora / Kali Linux / Debian 镜像源和 SSH 服务设置脚本

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

if [ "$DISTRO" = "fedora" ]; then
    # Fedora: 设置清华镜像源
    echo ">>> 设置 Fedora 清华镜像源..."
    sudo cp -r /etc/yum.repos.d /etc/yum.repos.d.bak
    sudo sed -e 's|^metalink=|#metalink=|g' \
             -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora|g' \
             -i /etc/yum.repos.d/fedora.repo /etc/yum.repos.d/fedora-updates.repo
    sudo dnf clean all
    sudo dnf makecache

    # 启用 SSH
    echo ">>> 启用 SSH 服务..."
    sudo systemctl enable sshd --now
    systemctl status sshd

elif [ "$DISTRO" = "kali" ]; then
    # Kali Linux: 设置清华镜像源
    echo ">>> 设置 Kali Linux 清华镜像源..."
    sudo cp -r /etc/apt/sources.list /etc/apt/sources.list.bak

    sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 清华大学镜像源 - Kali Linux
deb https://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main non-free non-free-firmware contrib
EOF

    sudo apt clean all
    sudo apt update

    # 启用 SSH
    echo ">>> 启用 SSH 服务..."
    sudo systemctl enable ssh --now
    systemctl status ssh

else
    # Debian: 设置清华镜像源
    echo ">>> 设置 Debian 清华镜像源..."
    sudo cp -r /etc/apt/sources.list /etc/apt/sources.list.bak

    DEBIAN_CODENAME=$(lsb_release -cs 2>/dev/null || cat /etc/debian_version | cut -d'/' -f1)
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 清华大学镜像源 - Debian
deb https://mirrors.tuna.tsinghua.edu.cn/debian ${DEBIAN_CODENAME} main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian ${DEBIAN_CODENAME}-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security ${DEBIAN_CODENAME}-security main contrib non-free non-free-firmware
EOF

    sudo apt clean all
    sudo apt update

    # 启用 SSH
    echo ">>> 启用 SSH 服务..."
    sudo systemctl enable ssh --now
    systemctl status ssh
fi

echo ">>> 镜像源和 SSH 服务设置完成!"
