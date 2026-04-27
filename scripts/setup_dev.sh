#!/bin/bash
# Fedora / Kali Linux / Debian Dev Environment Setup (Python + Java + C/C++)

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
        PKG_MANAGER="dnf"
        echo ">>> 检测到 Fedora 系统"
        ;;
    kali)
        PKG_MANAGER="apt"
        echo ">>> 检测到 Kali Linux 系统"
        ;;
    debian)
        PKG_MANAGER="apt"
        echo ">>> 检测到 Debian 系统"
        ;;
    *)
        echo "错误: 不支持的发行版"
        exit 1
        ;;
esac

echo ">>> 更新系统软件包..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf upgrade --refresh -y
else
    sudo apt update
    sudo apt upgrade -y
fi

echo ">>> 安装 Python & Haskell 开发环境..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y python3 python3-pip python3-virtualenv python3-devel autopep8 ghc
    pip3 install --upgrade pip ipython black flake8 mypy httplib2 redis tbomb
    pip3 install pynvim pyinstaller numpy pandas phone thread threadpool manim termdown
elif [ "$DISTRO" = "kali" ]; then
    # Kali - 基础包，使用 pipx
    sudo apt install -y python3 python3-pip python3-venv python3-dev ghc pipx
    pipx ensurepath
    export PATH="$HOME/.local/bin:$PATH"
    pipx install --upgrade pip ipython black flake8 mypy autopep8 httplib2 redis
    pipx install pynvim pyinstaller numpy pandas phone thread threadpool tbomb
else
    # Debian - 更全面的 Python 开发环境，使用 pipx 对应 Fedora 的 pip3
    sudo apt install -y python3 python3-pip python3-venv python3-dev python3-full
    sudo apt install -y ghc pipx python3-sphinx python3-pytest python3-tox python3-nose
    sudo apt install -y python3-wheel python3-setuptools
    pipx ensurepath
    export PATH="$HOME/.local/bin:$PATH"
    # 与 Fedora pip3 对等的工具
    pipx install --upgrade pip ipython black flake8 mypy autopep8 httplib2 redis tbomb
    pipx install pynvim pyinstaller numpy pandas phone thread threadpool manim termdown
    # Debian 额外的工具
    pipx install pylint virtualenv isort
fi

echo ">>> 现在开始安装Haskell,请记得勾选下载Haskell的language-server..."
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
# 加载 GHCup 环境变量
[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"
cabal update
cabal install stylish-haskell

echo ">>> 安装 Java"
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y java-latest-openjdk java-latest-openjdk-devel maven gradle
elif [ "$DISTRO" = "kali" ]; then
    # Kali - 基础 JDK
    sudo apt install -y openjdk-21-jdk maven gradle
else
    # Debian - 更全面的 Java 开发环境
    sudo apt install -y openjdk-21-jdk maven gradle
    sudo apt install -y ant default-jdk-headless java-common || true
fi

echo ">>> 安装 Golang"
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y golang
    go install golang.org/x/tools/gopls@latest
elif [ "$DISTRO" = "debian" ]; then
    sudo apt install -y golang-go
    go install golang.org/x/tools/gopls@latest
fi
# Kali 不自动安装 Golang，用户可按需安装

echo ">>> 安装 Rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# 加载 Rust 环境变量
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
rustup component add rust-analyzer
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y chafa
else
    sudo apt install -y chafa
fi

echo ">>> 安装 C/C++ 工具链..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y gcc gcc-c++ gdb cmake make automake autoconf libtool ninja-build astyle conda latexmk clang-tools-extra
elif [ "$DISTRO" = "kali" ]; then
    # Kali - 基础工具链
    sudo apt install -y build-essential gcc g++ gdb cmake make automake autoconf libtool ninja-build astyle latexmk
else
    # Debian - 更全面的 C/C++ 工具链
    sudo apt install -y build-essential gcc g++ gdb cmake make automake autoconf libtool ninja-build astyle latexmk
    sudo apt install -y clang clangd lldb clang-format clang-tidy || true
    sudo apt install -y cppcheck valgrind || true
    sudo apt install -y pkg-config ccache || true
fi

cd ~/Downloads
wget "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%400.15.0/tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz"
gunzip ./tectonic-0.15.0-x86_64-unknown-linux-gnu.tar.gz
tar -xf tectonic-0.15.0-x86_64-unknown-linux-gnu.tar
mkdir -p ~/tectonic
mv ./tectonic ~/tectonic
ln -sf ~/tectonic/tectonic ~/.local/bin

echo ">>> 安装常用科学/图形库..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y SDL2-devel mesa-libGL-devel mesa-libEGL-devel gsl-devel fftw-devel openmpi-devel || true
    sudo dnf install -y ctags
elif [ "$DISTRO" = "kali" ]; then
    # Kali - 基础库
    sudo apt install -y libsdl2-dev libgl1-mesa-dev libegl1-mesa-dev libgsl-dev libfftw-dev libopenmpi-dev || true
    sudo apt install -y universal-ctags
else
    # Debian - 更全面的开发库
    sudo apt install -y libsdl2-dev libgl1-mesa-dev libegl1-mesa-dev libgsl-dev libfftw-dev libopenmpi-dev || true
    sudo apt install -y libboost-all-dev libeigen3-dev libopencv-dev || true
    sudo apt install -y libssl-dev libcurl4-openssl-dev libjson-c-dev || true
    sudo apt install -y libsqlite3-dev libpq-dev libmysqlclient-dev || true
    sudo apt install -y universal-ctags
fi

echo ">>> 安装汇编语言工具..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y ltrace yasm strace nasm
else
    sudo apt install -y ltrace yasm strace nasm
fi

echo ">>> Verifying..."
python3 --version
pip3 --version
java -version
javac -version
mvn -version
if [ "$DISTRO" = "fedora" ]; then
    gradle -v
else
    gradle --version
fi
g++ --version
cmake --version
nasm --version
yasm --version

echo ">>> 执行vim命令..."
vim -c "PlugInstall"
vim -c "CocInstall coc-java"
vim -c "CocInstall coc-rust-analyzer"

echo ">>> Finished! 🚀 运行'install-coc-servers.sh'来完成nvim语言服务器的配置"
echo ">>> 注意：请重新打开终端或运行 'source ~/.ghcup/env && source ~/.cargo/env' 以使 Haskell 和 Rust 环境生效"