#!/bin/bash
# Fedora Dev Environment Setup (Python + Java + C/C++)

set -e

echo ">>> 更新系统软件包..."
sudo dnf upgrade --refresh -y

echo ">>> 安装 Python 开发环境..."
sudo dnf install -y python3 python3-pip python3-virtualenv python3-devel
pip3 install --upgrade pip ipython black flake8 mypy

echo ">>> 安装 Java "
sudo dnf install -y java-latest-openjdk java-latest-openjdk-devel maven gradle

echo ">>> 安装 C/C++ 工具链..."
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y gcc gcc-c++ gdb cmake make automake autoconf libtool ninja-build

echo ">>> 可选: 安装常用科学/图形库..."
sudo dnf install -y SDL2-devel mesa-libGL-devel mesa-libEGL-devel gsl-devel fftw-devel openmpi-devel || true
echo ">>> Verifying..."
python3 --version
pip3 --version
java -version
javac -version
mvn -version
gradle -v
g++ --version
cmake --version

echo ">>> Finished! 🚀"

