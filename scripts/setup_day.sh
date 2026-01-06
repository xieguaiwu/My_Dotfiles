#!/bin/bash
# Fedora 41+

set -e

echo ">>> Setting root password..."
sudo passwd root

echo ">>> 更新系统软件包..."
sudo dnf upgrade --refresh -y
sudo dnf install -y curl git npm wget gawk node yacc fastfetch pinta
sudo dnf install -y clash-verge flatpak shotcut eyeD3 exiftool qpdf
sudo dnf install -y fcitx5 fcitx5-chinese-addons fcitx5-configtool fcitx5-qt fcitx5-gtk xorg-x11-font-utils cabextract

echo ">>> Installing fish shell and wezterm..."
sudo dnf install -y fish
sudo dnf install -y https://github.com/wezterm/wezterm/releases/download/20240203-110809-5046fc22/wezterm-20240203_110809_5046fc22-1.fedora39.x86_64.rpm
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

echo ">>> Copying config files..."
git clone https://github.com/xieguaiwu/My_Dotfiles
mkdir ~/.config/fish
mv ~/My_Dotfiles/config.fish ~/.config

echo ">>> Installing text editors..."
sudo dnf install -y vim nvim

mv ~/My_Dotfiles/vimrc ~/.vimrc
mv ~/My_Dotfiles/nethackrc ~/.nethackrc
mkdir ~/.vim
mkdir ~/.vim/autoload
git clone https://github.com/junegunn/vim-plug
mv ~/vim-plug/plug.vim ~/.vim/autoload

mv ~/My_Dotfiles/nvim ~/.config
cd ~
git clone https://github.com/folke/lazy.nvim
mkdir ~/.local/share/nvim
mkdir ~/.local/share/nvim/lazy
mv ~/lazy.nvim ~/.local/share/nvim/lazy

cd ~
mkdir ./obsidian
cd ./obsidian
wget "https://github.com/obsidianmd/obsidian-releases/releases/download/v1.9.12/Obsidian-1.9.12.AppImage"
chmod +x ./Obsidian-1.9.12.AppImage

sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
sudo dnf config-manager addrepo --from-repofile=https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
sudo dnf install sublime-text

echo ">>> Installing yazi..."
sudo dnf copr enable lihaohong/yazi
sudo dnf install -y yazi
mv ~/My_Dotfiles/yazi ~/.config/

echo ">>> Installing funny stuff..."
sudo dnf copr enable dejan/lazygit
sudo dnf install -y lsd nethack ncdu lazygit btop pandoc cowsay cbonsai tldr  
tldr --update
mv ~/My_Dotfiles/lazygit ~/.config/
sudo npm install -g @mermaid-js/mermaid-cli
mv ~/My_Dotfiles/mermaid ~/.config/
npx puppeteer browsers install chrome-headless-shell

sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
# download microsoft font installer

cd ~
git clone https://github.com/andmarti1424/sc-im/
cd sc-im/src
make -C src
sudo make -C src install
mv ~/My_Dotfiles/sc-im ~/.config/

cd ~
git clone https://github.com/abishekvashok/cmatrix
mkdir cmatrix/build
cd cmatrix/build
cmake ..
make
sudo make install
flatpak install flathub org.telegram.desktop

cd ~/Downloads
wget "https://github.com/erkyrath/lectrote/releases/tag/lectrote-1.5.5/Lectrote-1.5.5-linux-x64.zip"
wget "https://github.com/imsyy/SPlayer/releases/download/v3.0.0-beta.2/splayer-3.0.0-beta.2.x86_64.rpm"
sudo dnf install ./splayer-3.0.0-beta.2.x86_64.rpm

cd ~/Downloads
wget "https://github.com/hiroi-sora/Umi-OCR/releases/download/v2.1.5/Umi-OCR_Linux_Paddle_2.1.5.tar.xz"
xz -d ./Umi-OCR_Linux_Paddle_2.1.5.tar.xz
tar -xf ./Umi-OCR_Linux_Paddle_2.1.5.tar
mv ./Umi-OCR_Linux_Paddle_2.1.5 ~/umi-ocr
cd ~/umi-ocr
sh ./umi-ocr.sh

cd ~/Downloads
sudo dnf install dictzip
wget "https://download.freedict.org/dictionaries/deu-eng/1.9-fd1/freedict-deu-eng-1.9-fd1.dictd.tar.xz"
xz -d ./freedict-deu-eng-1.9-fd1.dictd.tar.xz
tar -xf ./freedict-deu-eng-1.9-fd1.dictd.tar
cd ./deu-eng
dictzip -d ./deu-eng.dict.dz
sudo mv deu-eng.dict /usr/share/dict/dictd/
sudo mv deu-eng.index /usr/share/dict/dictd/
sudo systemctl restart dictd

cd ~
wget "https://victornils.net/tetris/vitetris-0.55-i486-linux.tar.gz"
gunzip ./vitetris-0.55-i486-linux.tar.gz
tar -xf vitetris-0.55-i486-linux.tar
rm vitetris-0.55-i486-linux.tar

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

echo ">>> Installing sway stuff"
sudo dnf install -y sway waybar NetworkManager-tui network-manager-applet 
sudo dnf install -y dunst wofi pulse brightnessctl pactl libinput
sudo dnf install -y arandr nm-applet blueman-applet lxappearance
mv ~/My_Dotfiles/sway ~/.config
mv ~/My_Dotfiles/swaylock ~/.config
mv ~/My_Dotfiles/wofi ~/.config
mv ~/My_Dotfiles/waybar ~/.config
mv ~/My_Dotfiles/timer ~
echo ">>> Finished! 🚀 Now remember to download JetBrain Mono, calibre... Then move config files in My_Dotfiles to your local position."
