#!/bin/bash
# Fedora 41+

set -e

echo ">>> 更新系统软件包..."
sudo dnf upgrade --refresh -y
sudo dnf install -y curl git npm wget gawk node
sudo dnf install -y clash-verge

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

curl "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.9.12/Obsidian-1.9.12.AppImage"

sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
sudo dnf config-manager addrepo --from-repofile=https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo

echo ">>> Installing yazi..."
sudo dnf copr enable lihaohong/yazi
sudo dnf install -y yazi

echo ">>> Installing funny stuff..."
sudo dnf copr enable dejan/lazygit
sudo dnf install -y lazygit
sudo dnf install -y lsd nethack ncdu btop pandoc 
git clone https://github.com/maaslalani/slides
sudo npm install -g @mermaid-js/mermaid-cli
git clone https://github.com/andmarti1424/sc-im/
sudo dnf install -y tldr
tldr --update

echo ">>> Installing translation tools"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Karmenzind/kd/master/scripts/install.sh)"
gawk -f (curl -Ls --compressed https://git.io/translate | psub) -- -shell

echo ">>> Downloading graphic dependencies"
sudo dnf install -y gcc-c++ make cmake SDL2-devel SDL2_mixer-devel SDL2_net-devel git \
zlib-devel bzip2-devel libjpeg-turbo-devel gtk2-devel SDL-devel SDL_mixer-devel \
SDL_net-devel
mkdir -pv ~/ecwolf_build
cd ~/ecwolf_build
git clone https://bitbucket.org/ecwolf/ecwolf.git
mkdir -pv ecwolf/build
cd ~

echo ">>> Finished! 🚀 Now remember to download JetBrain Mono, calibre... Then move config files in My_Dotfiles to your local position."

