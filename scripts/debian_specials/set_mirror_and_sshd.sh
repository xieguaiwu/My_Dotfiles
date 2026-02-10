#!/bin/bash
# debian Linux 镜像源和 SSH 服务设置脚本

set -e

# 备份 sources.list
sudo cp -r /etc/apt/sources.list /etc/apt/sources.list.bak

# 设置清华大学镜像源
sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 清华大学镜像源 - Kali Linux
deb https://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main non-free non-free-firmware contrib
EOF

# 更新软件包列表
sudo apt clean all
sudo apt update

# 启用并启动 SSH 服务
sudo systemctl enable ssh --now
systemctl status ssh
