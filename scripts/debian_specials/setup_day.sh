#!/bin/bash
# Debian Linux

set -e

echo "You can use 'sudo passwd root' to set the root password..."
echo ">>> 更新系统软件包..."
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl git npm wget gawk nodejs fastfetch
sudo apt install -y flatpak eyed3 qpdf cava fcitx5 fcitx5-chinese-addons fcitx5-pinyin
# fcitx5-configtool fcitx5-qt5 fcitx5-gtk3 xfonts-utils cabextract

cd ~/Downloads
wget "https://github.com/clash-verge-rev/clash-verge-rev/releases/download/v2.4.5/Clash.Verge_2.4.5_amd64.deb"
sudo apt install -y ./Clash.Verge_2.4.5_amd64.deb

npm i -g @iflow-ai/iflow-cli

git clone "https://github.com/junegunn/vim-plug.git"
mkdir ~/.vim/autoload
mv ./vim-plug/plug.vim ~/.vim/autoload

echo ">>> Installing fish shell and wezterm..."
sudo apt install -y fish

curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list
sudo chmod 644 /usr/share/keyrings/wezterm-fury.gpg
sudo apt update
sudo apt install wezterm

curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

echo ">>> Copying config files..."
mkdir ~/.config/fish
mv ~/My_Dotfiles/config.fish ~/.config

echo ">>> Installing text editors..."
sudo apt install -y vim neovim

mv ~/My_Dotfiles/nvim ~/.config
cd ~
git clone https://github.com/folke/lazy.nvim
sudo mkdir /usr/share/nvim
sudo mkdir /usr/share/nvim/lazy
sudo mv ~/lazy.nvim /usr/share/nvim/lazy

wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null
echo -e 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc' | sudo tee /etc/apt/sources.list.d/sublime-text.sources
sudo apt update
sudo apt install sublime-text

echo ">>> Installing yazi..."
cd ~/Downloads
wget "https://github.com/sxyazi/yazi/releases/download/v26.1.22/yazi-x86_64-unknown-linux-gnu.deb"
sudo apt install -y ./yazi-x86_64-unknown-linux-gnu.deb
rm ./yazi-x86_64-unknown-linux-gnu.deb

echo ">>> Installing funny stuff..."
sudo apt install -y lsd ncdu lazygit btop pandoc cowsay cbonsai 
mv ~/My_Dotfiles/lazygit ~/.config/
sudo npm install -g @mermaid-js/mermaid-cli
mv ~/My_Dotfiles/mermaid ~/.config/
npx puppeteer browsers install chrome-headless-shell

sudo apt install -y ttf-mscorefonts-installer
echo ">>> Microsoft fonts installed (may need interaction)"

cd ~
git clone https://github.com/abishekvashok/cmatrix
mkdir cmatrix/build
cd cmatrix/build
cmake ..
make
sudo make install
flatpak install flathub org.telegram.desktop

cd ~/Downloads
wget "https://github.com/hiroi-sora/Umi-OCR/releases/download/v2.1.5/Umi-OCR_Linux_Paddle_2.1.5.tar.xz"
xz -d ./Umi-OCR_Linux_Paddle_2.1.5.tar.xz
tar -xf ./Umi-OCR_Linux_Paddle_2.1.5.tar
mv ./Umi-OCR_Linux_Paddle_2.1.5 ~/umi-ocr
cd ~/umi-ocr
sh ./umi-ocr.sh

cd ~/Downloads
sudo apt install dictzip dictd
wget "https://download.freedict.org/dictionaries/deu-eng/1.9-fd1/freedict-deu-eng-1.9-fd1.dictd.tar.xz"
xz -d ./freedict-deu-eng-1.9-fd1.dictd.tar.xz
tar -xf ./freedict-deu-eng-1.9-fd1.dictd.tar
cd ./deu-eng
dictzip -d ./deu-eng.dict.dz
sudo mv deu-eng.dict /usr/share/dictd/
sudo mv deu-eng.index /usr/share/dictd/
sudo systemctl restart dictd
cd ~
mv ./My_Dotfiles/scripts/de.sh ~/.local/bin
chmod +x ~/.local/bin/de.sh

cd ~
wget "https://victornils.net/tetris/vitetris-0.55-i486-linux.tar.gz"
gunzip ./vitetris-0.55-i486-linux.tar.gz
tar -xf vitetris-0.55-i486-linux.tar
rm vitetris-0.55-i486-linux.tar

echo ">>> Installing translation tools"
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Karmenzind/kd/master/scripts/install.sh)"
gawk -f <(curl -Ls --compressed https://git.io/translate) -- -shell
wget git.io/trans
chmod +x ./trans

echo ">>> Installing sway stuff"
sudo apt install -y sway waybar network-manager network-manager-gnome
sudo apt install -y dunst wofi pulseaudio-utils brightnessctl pipewire-audio-client-libraries libinput-bin
sudo apt install -y arandr blueman lxappearance
mv ~/My_Dotfiles/sway ~/.config
mv ~/My_Dotfiles/swaylock ~/.config
mv ~/My_Dotfiles/wofi ~/.config
mv ~/My_Dotfiles/waybar ~/.config
mv ~/My_Dotfiles/timer ~
echo ">>> Finished! 🚀 Now remember to download JetBrain Mono, calibre... Then move config files in My_Dotfiles to your local position."
