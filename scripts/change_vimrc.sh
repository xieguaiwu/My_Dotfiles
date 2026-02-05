#!/bin/bash
set -e
cd ~
git clone https://github.com/xieguaiwu/My_Vim
mv ~/My_Vim/vimrc ~/.vimrc
vim ~/.vimrc
vim -c "so" -c "q"
