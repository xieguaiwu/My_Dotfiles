# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi

unset rc
export http_proxy="http://127.0.0.1:7897"
export https_proxy="http://127.0.0.1:7897"
export all_proxy="socks5://127.0.0.1:7897"
export PUPPETEER_EXECUTABLE_PATH=/home/xieguiawu/.cache/puppeteer/chrome/linux-149.0.7827.22/chrome-linux64/chrome

. "$HOME/.cargo/env"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/usr/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/usr/etc/profile.d/conda.sh" ]; then
        . "/usr/etc/profile.d/conda.sh"
    else
        export PATH="/usr/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PATH="$HOME/.npm-global/bin:$PATH"
export PATH="$HOME/.local/julia/bin:$PATH"

# Pentest AI Toolkit 别名
alias pentest-deepseek='pentestgpt-legacy --reasoning-model deepseek-v4-flash --parsing-model deepseek-v4-flash --generation-model deepseek-v4-flash'
alias ptai-scan='ptai scan'
alias bettercap='~/go/bin/bettercap'
alias pentest-lab='cd ~/pentest-ai && ls -la'
