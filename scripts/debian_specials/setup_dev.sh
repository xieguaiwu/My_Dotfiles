#!/bin/bash
# Debian Linux Dev Environment Setup (Python + Java + C/C++)

set -e

echo ">>> 更新系统软件包..."
sudo apt update
sudo apt upgrade -y

echo ">>> 安装 Python & Haskell 开发环境..."
sudo apt install -y python3 python3-pip python3-venv python3-dev ghc
pipx install --upgrade pip ipython black flake8 mypy autopep8 httplib2 redis
pipx install pynvim pyinstaller numpy pandas phone thread threadpool tbomb
echo ">>> 现在开始安装Haskell,请记得勾选下载Haskell的language-server..."
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
cabal update
cabal install stylish-haskell

echo ">>> 安装 Java"
sudo apt install -y openjdk-21-jdk maven gradle

echo ">>> 安装 Rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-analyzer
sudo apt install -y chafa

echo ">>> 安装 C/C++ 工具链..."
sudo apt install -y build-essential gcc g++ gdb cmake make automake autoconf libtool ninja-build astyle latexmk

cd ~/Downloads
wget "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.15.0/tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz"
gunzip ./tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz
tar -xf tectonic-0.15.0-x86_64-unknown-linux-gnu.tar
mkdir ~/tectonic
mv ./tectonic ~/tectonic
ln -s ~/tectonic/tectonic ~/.local/bin

echo ">>> 安装常用科学/图形库..."
sudo apt install -y libsdl2-dev libgl1-mesa-dev libegl1-mesa-dev libgsl-dev libfftw-dev libopenmpi-dev || true
sudo apt install -y universal-ctags

echo ">>> 安装汇编语言工具..."
sudo apt install -y ltrace yasm strace nasm

echo ">>> Verifying..."
python3 --version
pip3 --version
java -version
javac -version
mvn -version
gradle --version
g++ --version
cmake --version
nasm --version
yasm --version

echo ">>> 执行vim命令..."
vim -c "PlugInstall"
vim -c "CocInstall coc-java"
vim -c "CocInstall coc-rust-analyzer"

echo ">>> Finished! 🚀 运行'install-coc-servers.sh'来完成nvim语言服务器的配置"
