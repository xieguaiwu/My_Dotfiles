#!/bin/bash
set -e
cd ~
# 检查是否已存在 My_Vim 目录
if [ -d "My_Vim" ]; then
    echo ">>> My_Vim 目录已存在，跳过克隆"
else
    git clone https://github.com/xieguaiwu/My_Vim
fi
# 使用 -f 强制覆盖已存在的文件
[ -f ~/My_Vim/vimrc ] && mv -f ~/My_Vim/vimrc ~/.vimrc
vim ~/.vimrc
vim -c "so" -c "q"