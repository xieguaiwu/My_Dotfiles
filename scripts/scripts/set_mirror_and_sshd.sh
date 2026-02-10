#for Fedora 39+

set -e

sudo cp -r /etc/yum.repos.d /etc/yum.repos.d.bak
sudo sed -e 's|^metalink=|#metalink=|g' \
         -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora|g' \
         -i /etc/yum.repos.d/fedora.repo /etc/yum.repos.d/fedora-updates.repo
sudo dnf clean all
sudo dnf makecache

sudo systemctl enable sshd --now
systemctl status sshd
