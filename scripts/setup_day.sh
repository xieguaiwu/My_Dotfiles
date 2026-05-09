#!/bin/bash
# Fedora 41+ / Kali Linux / Debian (Unified)

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

echo ">>> You can use 'sudo passwd root' to set the root password..."
echo ">>> 更新系统软件包..."

if [ "$DISTRO" = "fedora" ]; then
    sudo dnf upgrade --refresh -y
    sudo dnf install -y curl git npm wget gawk node yacc fastfetch pinta wireguard-tools vlc parole glow timg qalculate
    sudo dnf install -y clash-verge flatpak shotcut eyeD3 exiftool qpdf chromium cava openssh-server alien gnome-keyring
    sudo dnf install -y fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-qt fcitx5-gtk xorg-x11-font-utils cabextract
elif [ "$DISTRO" = "kali" ]; then
    # Kali Linux - 安全工具预装较多，安装日常软件
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl git npm wget gawk nodejs fastfetch wireguard steghide vlc parole timg qalculate
    sudo apt install -y flatpak eyed3 qpdf cava fcitx5 fcitx5-chinese-addons fcitx5-pinyin glow
else
    # 标准 Debian
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl git npm wget gawk nodejs fastfetch wireguard steghide vlc parole timg qalculate
    sudo apt install -y flatpak eyed3 qpdf cava fcitx5 fcitx5-chinese-addons fcitx5-pinyin glow
fi

flatpak install flathub hu.irl.cameractrls

cd ~/Downloads
mkdir -p ~/.vim/autoload

if [ "$DISTRO" = "fedora" ]; then
    [ ! -d "$HOME/vim-plug" ] && git clone https://github.com/junegunn/vim-plug
    [ -f "$HOME/vim-plug/plug.vim" ] && mv -f ~/vim-plug/plug.vim ~/.vim/autoload
else
    [ ! -d "./vim-plug" ] && git clone "https://github.com/junegunn/vim-plug.git"
    [ -f "./vim-plug/plug.vim" ] && mv -f ./vim-plug/plug.vim ~/.vim/autoload
fi

echo ">>> Installing fish shell and wezterm..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y fish
    sudo dnf install -y https://github.com/wezterm/wezterm/releases/download/20240203-110809-5046fc22/wezterm-20240203_110809_5046fc22-1.fedora39.x86_64.rpm
else
    # Kali 和 Debian 使用相同的方式
    sudo apt install -y fish
    
    curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
    sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
    sudo apt update
    sudo apt install wezterm
fi

echo ">>> Installing fisher (fish shell plugin manager)..."
# 使用 fish -c 在 fish shell 中执行 fisher 安装
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" || echo "fisher 安装可能需要手动执行"

echo ">>> Copying config files..."
mkdir -p ~/.config/fish
[ -f ~/My_Dotfiles/config.fish ] && mv -f ~/My_Dotfiles/config.fish ~/.config

cd ~/Downloads
if [ "$DISTRO" = "fedora" ]; then
    wget -nc "https://github.com/sheeki03/tirith/releases/download/v0.1.9/tirith-0.1.9-1.el9.x86_64.rpm"
    sudo dnf -y install ./tirith-0.1.9-1.el9.x86_64.rpm
else
    wget -nc "https://github.com/sheeki03/tirith/releases/download/v0.1.9/tirith_0.1.9_amd64.deb"
    sudo apt -y install ./tirith_0.1.9_amd64.deb
fi

echo ">>> Installing text editors..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y vim nvim
else
    sudo apt install -y vim neovim
fi

if [ "$DISTRO" = "fedora" ]; then
    [ -f ~/My_Dotfiles/vimrc ] && mv -f ~/My_Dotfiles/vimrc ~/.vimrc
    [ -f ~/My_Dotfiles/nethackrc ] && mv -f ~/My_Dotfiles/nethackrc ~/.nethackrc
fi

[ -d ~/My_Dotfiles/nvim ] && mv -f ~/My_Dotfiles/nvim ~/.config
cd ~
[ ! -d "$HOME/lazy.nvim" ] && git clone https://github.com/folke/lazy.nvim
if [ "$DISTRO" = "fedora" ]; then
    mkdir -p ~/.local/share/nvim/lazy
    mv -f ~/lazy.nvim ~/.local/share/nvim/lazy
else
    sudo mkdir -p /usr/share/nvim/lazy
    sudo mv -f ~/lazy.nvim /usr/share/nvim/lazy
fi

if [ "$DISTRO" = "fedora" ]; then
    cd ~
    mkdir -p ./obsidian
    cd ./obsidian
    wget -nc "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.9.12/Obsidian-1.9.12.AppImage"
    chmod +x ./Obsidian-1.9.12.AppImage
fi

echo ">>> Downloading tor-browser, check 'https://bridges.torproject.org/options' to get a bridge"
cd ~/Downloads
wget -nc "https://www.torproject.org/dist/torbrowser/15.0.5/tor-browser-linux-x86_64-15.0.5.tar.xz"
xz -d -k ./tor-browser-linux-x86_64-15.0.5.tar.xz 2>/dev/null || true
tar -xf ./tor-browser-linux-x86_64-15.0.5.tar
mv -f ./tor-browser ~

if [ "$DISTRO" = "fedora" ]; then
    sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
    sudo dnf config-manager addrepo --from-repofile=https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
    sudo dnf install sublime-text
else
    wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null
    echo -e 'Types: deb\nURIs: https://download.sublimettext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc' | sudo tee /etc/apt/sources.list.d/sublime-text.sources
    sudo apt update
    sudo apt install sublime-text
fi

echo ">>> Installing yazi..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf copr enable -y lihaohong/yazi
    sudo dnf install -y yazi
else
    cd ~/Downloads
    wget -nc "https://github.com/sxyazi/yazi/releases/download/v26.1.22/yazi-x86_64-unknown-linux-gnu.deb"
    sudo apt install -y ./yazi-x86_64-unknown-linux-gnu.deb
    rm -f ./yazi-x86_64-unknown-linux-gnu.deb
fi
[ -d ~/My_Dotfiles/yazi ] && mv -f ~/My_Dotfiles/yazi ~/.config/

if [ "$DISTRO" = "fedora" ]; then
    sudo dnf copr enable -y mo-k12/personal
    sudo dnf install -y xdg-desktop-portal-termfilechooser
fi

echo ">>> Installing funny stuff..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf copr enable -y dejan/lazygit
    sudo dnf install -y lsd nethack ncdu lazygit btop pandoc cowsay cbonsai tldr
    tldr --update
else
    sudo apt install -y lsd ncdu lazygit btop pandoc cowsay cbonsai
fi

[ -d ~/My_Dotfiles/lazygit ] && mv -f ~/My_Dotfiles/lazygit ~/.config/
sudo npm install -g @mermaid-js/mermaid-cli
sudo npm install -g deepseek-tui
sudo npm install -g opencode-ai
[ -d ~/My_Dotfiles/mermaid ] && mv -f ~/My_Dotfiles/mermaid ~/.config/
npx puppeteer browsers install chrome-headless-shell

if [ "$DISTRO" = "fedora" ]; then
    sudo dnf copr enable -y poesty/go-musicfox
    sudo dnf install -y go-musicfox
else
    cd ~/Downloads
    wget -nc "https://github.com/go-musicfox/go-musicfox/releases/download/v4.8.0/go-musicfox_4.8.0_linux_amd64.deb"
    sudo apt install -y ./go-musicfox_4.8.0_linux_amd64.deb
fi

if [ "$DISTRO" = "fedora" ]; then
    sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
else
    sudo apt install -y ttf-mscorefonts-installer
    echo ">>> Microsoft fonts installed (may need interaction)"
fi

cd ~/Downloads
[ ! -d "Display_Latex_Expression" ] && git clone "https://github.com/xieguaiwu/Display_Latex_Expression.git"
cd ./Display_Latex_Expression
chmod +x ./Display
mkdir -p ~/.local/bin
mv -f ./Display ~/.local/bin

if [ "$DISTRO" = "fedora" ]; then
    [ -d ~/My_Dotfiles/sc-im ] && mv -f ~/My_Dotfiles/sc-im ~/.config/
    
    cd ~
    [ ! -d "sc-im" ] && git clone https://github.com/andmarti1424/sc-im/
    cd sc-im/src
    make -C src
    sudo make -C src install
fi

cd ~
[ ! -d "cmatrix" ] && git clone https://github.com/abishekvashok/cmatrix
mkdir -p cmatrix/build
cd cmatrix/build
cmake ..
make
sudo make install
flatpak install flathub org.telegram.desktop

if [ "$DISTRO" = "fedora" ]; then
    cd ~/Downloads
    wget -nc "https://github.com/erkyrath/lectrote/releases/tag/lectrote-1.5.5/Lectrote-1.5.5-linux-x64.zip"
    wget -nc "https://github.com/imsyy/SPlayer/releases/download/v3.0.0-beta.2/splayer-3.0.0-beta.2.x86_64.rpm"
    sudo dnf install ./splayer-3.0.0-beta.2.x86_64.rpm
fi

cd ~/Downloads
wget -nc "https://github.com/hiroi-sora/Umi-OCR/releases/download/v2.1.5/Umi-OCR_Linux_Paddle_2.1.5.tar.xz"
xz -d -k ./Umi-OCR_Linux_Paddle_2.1.5.tar.xz 2>/dev/null || true
tar -xf ./Umi-OCR_Linux_Paddle_2.1.5.tar
mv -f ./Umi-OCR_Linux_Paddle_2.1.5 ~/umi-ocr
echo ">>> Umi-OCR 已解压到 ~/umi-ocr，请手动运行 sh ~/umi-ocr/umi-ocr.sh"

cd ~/Downloads
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y dictzip
else
    sudo apt install -y dictzip dictd
fi

wget -nc "https://download.freedict.org/dictionaries/deu-eng/1.9-fd1/freedict-deu-eng-1.9-fd1.dictd.tar.xz"
xz -d -k ./freedict-deu-eng-1.9-fd1.dictd.tar.xz 2>/dev/null || true
tar -xf ./freedict-deu-eng-1.9-fd1.dictd.tar
cd ./deu-eng
dictzip -d ./deu-eng.dict.dz
if [ "$DISTRO" = "fedora" ]; then
    sudo mkdir -p /usr/share/dict/dictd/
    sudo mv -f deu-eng.dict /usr/share/dict/dictd/
    sudo mv -f deu-eng.index /usr/share/dict/dictd/
    sudo systemctl restart dictd
else
    sudo mkdir -p /usr/share/dictd/
    sudo mv -f deu-eng.dict /usr/share/dictd/
    sudo mv -f deu-eng.index /usr/share/dictd/
    sudo systemctl restart dictd
fi

cd ~
mkdir -p ~/.local/bin
[ -f ./My_Dotfiles/scripts/de.sh ] && mv -f ./My_Dotfiles/scripts/de.sh ~/.local/bin
chmod +x ~/.local/bin/de.sh

cd ~
wget -nc "https://victornils.net/tetris/vitetris-0.55-i486-linux.tar.gz"
gunzip -f ./vitetris-0.55-i486-linux.tar.gz 2>/dev/null || true
tar -xf vitetris-0.55-i486-linux.tar
rm -f vitetris-0.55-i486-linux.tar

echo ">>> Installing translation tools"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Karmenzind/kd/master/scripts/install.sh)"
gawk -f <(curl -Ls --compressed https://git.io/translate) -- -shell
wget -nc git.io/trans
chmod +x ./trans

if [ "$DISTRO" = "fedora" ]; then
    echo ">>> Downloading graphic dependencies"
    sudo dnf install -y gcc-c++ make cmake SDL2-devel SDL2_mixer-devel SDL2_net-devel git \
    zlib-devel bzip2-devel libjpeg-turbo-devel gtk2-devel SDL-devel SDL_mixer-devel \
    SDL_net-devel
    git clone https://bitbucket.org/ecwolf/ecwolf.git
    mkdir -p ecwolf/build
    cd ecwolf/build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DGPL=ON
    make
    cd ~
fi

echo ">>> Installing common media libraries..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y ffmpeg ffmpeg-devel gstreamer1-plugins-good gstreamer1-plugins-bad-free \
    gstreamer1-plugins-ugly-free gstreamer1-libav libavcodec-freeworld || true
    sudo dnf install -y libogg libvorbis flac opus taglib libid3tag libmad libtheora libvpx || true
    sudo dnf install -y ImageMagick feh ffmpegthumbnailer || true
elif [ "$DISTRO" = "kali" ]; then
    sudo apt install -y ffmpeg libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-libav || true
    sudo apt install -y libogg-dev libvorbis-dev libflac-dev libopus-dev libtag1-dev libid3tag0-dev \
    libmad0-dev libtheora-dev libvpx-dev || true
    sudo apt install -y imagemagick feh ffmpegthumbnailer || true
else
    sudo apt install -y ffmpeg libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-libav || true
    sudo apt install -y libogg-dev libvorbis-dev libflac-dev libopus-dev libtag1-dev libid3tag0-dev \
    libmad0-dev libtheora-dev libvpx-dev || true
    sudo apt install -y imagemagick feh ffmpegthumbnailer || true
fi

echo ">>> Installing sway stuff..."
if [ "$DISTRO" = "fedora" ]; then
    sudo dnf install -y sway waybar NetworkManager-tui network-manager-applet
    sudo dnf install -y dunst wofi pulse brightnessctl pactl libinput tesseract
    sudo dnf install -y arandr nm-applet blueman-applet lxappearance swaylock
else
    # Kali 和 Debian 使用相同的包名
    sudo apt install -y sway waybar network-manager network-manager-gnome swaylock tesseract
    sudo apt install -y dunst wofi pulseaudio-utils brightnessctl pipewire-audio-client-libraries libinput-bin
    sudo apt install -y arandr blueman lxappearance
fi

[ -d ~/My_Dotfiles/sway ] && mv -f ~/My_Dotfiles/sway ~/.config
[ -d ~/My_Dotfiles/swaylock ] && mv -f ~/My_Dotfiles/swaylock ~/.config
[ -d ~/My_Dotfiles/wofi ] && mv -f ~/My_Dotfiles/wofi ~/.config
[ -d ~/My_Dotfiles/waybar ] && mv -f ~/My_Dotfiles/waybar ~/.config
[ -d ~/My_Dotfiles/timer ] && mv -f ~/My_Dotfiles/timer ~

if [ "$DISTRO" = "fedora" ]; then
    echo ">>> Installing email stuff"
    cd ~/Downloads
    wget -nc "https://proton.me/download/bridge/protonmail-bridge-3.21.2-1.x86_64.rpm"
    sudo dnf install -y ./protonmail-bridge-3.21.2-1.x86_64.rpm
    sudo dnf install -y alpine
fi

echo ">>> Finished! 🚀 Now remember to download JetBrain Mono, calibre... Then move config files in My_Dotfiles to your local position."
