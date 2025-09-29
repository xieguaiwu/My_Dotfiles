#!/bin/bash
# Fedora 41+

set -e

echo ">>> Setting root password..."
sudo passwd root

echo ">>> 更新系统软件包..."
sudo dnf upgrade --refresh -y
sudo dnf install -y curl git npm wget gawk node yacc
sudo dnf install -y clash-verge flatpak
sudo dnf install -y fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-qt fcitx5-gtk

echo ">>> Installing fish shell and wezterm..."
sudo dnf install -y fish
sudo dnf install -y https://github.com/wezterm/wezterm/releases/download/20240203-110809-5046fc22/wezterm-20240203_110809_5046fc22-1.fedora39.x86_64.rpm
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

echo ">>> Copying config files..."
git clone https://github.com/xieguaiwu/My_Dotfiles

echo ">>> Installing text editors..."
sudo dnf install -y vim nvim
mv ~/My_Dotfiles/home_vimrc ~/.vimrc
mv ~/My_Dotfiles/nethackrc ~/.nethackrc
mkdir ~/.vim
mkdir ~/.vim/autoload
git clone https://github.com/junegunn/vim-plug
mv ~/vim-plug ~/.vim/autoload

wget "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.9.12/Obsidian-1.9.12.AppImage"

sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
sudo dnf config-manager addrepo --from-repofile=https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
sudo dnf install sublime-text

echo ">>> Installing yazi..."
sudo dnf copr enable lihaohong/yazi
sudo dnf install -y yazi

echo ">>> Installing funny stuff..."
sudo dnf copr enable dejan/lazygit
sudo dnf install -y lazygit
sudo dnf install -y lsd nethack ncdu btop pandoc 
sudo npm install -g @mermaid-js/mermaid-cli
git clone https://github.com/andmarti1424/sc-im/
sudo dnf install -y tldr
tldr --update
flatpak install flathub org.telegram.desktop
wget "https://github.com/erkyrath/lectrote/releases/tag/lectrote-1.5.5/Lectrote-1.5.5-linux-x64.zip"
wget "https://github.com/imsyy/SPlayer/releases/download/v3.0.0-beta.2/splayer-3.0.0-beta.2.x86_64.rpm"
sudo dnf install ./splayer-3.0.0-beta.2.x86_64.rpm

echo ">>> Installing translation tools"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Karmenzind/kd/master/scripts/install.sh)"
gawk -f (curl -Ls --compressed https://git.io/translate | psub) -- -shell
wget git.io/trans
chmod +x ./trans

echo ">>> Downloading graphic dependencies"
sudo dnf install -y gcc-c++ make cmake SDL2-devel SDL2_mixer-devel SDL2_net-devel git \
zlib-devel bzip2-devel libjpeg-turbo-devel gtk2-devel SDL-devel SDL_mixer-devel \
SDL_net-devel
git clone https://bitbucket.org/ecwolf/ecwolf.git
mkdir ecwolf/build
cd ecwolf/build
cmake .. -DCMAKE_BUILD_TYPE=Release -DGPL=ON
make
cd ~
sudo dnf install -y obs-studio

echo ">>> Installing i3 stuff"
sudo dnf install -y xinput xset dunst waybar rofi i3 pulse picom brightnessctl pactl xautolock xss-lock
sudo dnf install -y arandr nm-applet blueman-applet lxappearance
echo ">>> Finished! 🚀 Now remember to download JetBrain Mono, calibre... Then move config files in My_Dotfiles to your local position."
