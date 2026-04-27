#!/bin/bash
# Fedora Dev Environment Setup (Python + Java + C/C++)

set -e

echo ">>> 更新系统软件包..."
sudo dnf upgrade --refresh -y

echo ">>> 安装 Python 开发环境..."
sudo dnf install -y python3 python3-pip python3-virtualenv python3-devel autopep8
pip3 install --upgrade pip ipython black flake8 mypy
pip3 install pynvim pyinstaller numpy pandas

echo ">>> 安装 Java "
sudo dnf install -y java-latest-openjdk java-latest-openjdk-devel maven gradle

echo ">>> 安装 Rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-analyzer
sudo dnf install -y chafa

echo ">>> 安装 C/C++ 工具链..."
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y gcc gcc-c++ gdb cmake make automake autoconf libtool ninja-build astyle conda latexmk

cd ~/Downloads
wget "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.15.0/tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz"
gunzip ./tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz
tar -xf tectonic-0.15.0-x86_64-unknown-linux-gnu.tar
mkdir ~/tectonic
mv ./tectonic ~/tectonic
ln -s ~/tectonic/tectonic ~/.local/bin

echo ">>> 安装常用科学/图形库..."
sudo dnf install -y SDL2-devel mesa-libGL-devel mesa-libEGL-devel gsl-devel fftw-devel openmpi-devel openblas-devel || true
sudo dnf install -y ctags

echo ">>> 安装汇编语言工具..."
sudo dnf install -y ltrace yasm strace nasm

echo ">>> Verifying..."
python3 --version
pip3 --version
java -version
javac -version
mvn -version
gradle -v
g++ --version
cmake --version
nasm --version
yasm --version

echo ">>> 执行vim命令..."
vim -c "PlugInstall"
vim -c "CocInstall coc-java"
vim -c "CocInstall coc-rust-analyzer"

echo ">>> Finished! 🚀"

