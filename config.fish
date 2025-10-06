if status is-interactive
    # Commands to run in interactive sessions can go here
end

if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end
if not contains $HOME/.local/bin $PATH
    set -gx PATH $HOME/.local/bin $PATH
end
if not contains $HOME/.cargo/bin $PATH
    set -gx PATH $HOME/.cargo/bin:$PATH
end

# 默认编辑器
set -gx EDITOR vim
set -gx VISUAL vim

# ==== 常用别名 ====
alias ll='ls -lh'
alias la='ls -lha'
alias lsl='lsd --long --human-readable --all'
alias lsa='lsd -a'
alias ..='cd ..'
alias ...='cd ../..'

# Git 常用
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

alias update='sudo dnf update -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'


# ~/.config/fish/config.fish
function mkcd
    mkdir -p $argv
    cd $argv
end

# Git 快速分支切换
function gco
    git checkout $argv
end

function fish_prompt
    set_color cyan
    echo -n (whoami)"@"(hostname) " "
    set_color yellow
    echo -n (prompt_pwd) " "
    set_color green
    echo -n (date "+%H:%M")" "
    set_color magenta
    echo -n "❯ "
    set_color normal
end

# fisher install jethrokuan/z
# fisher install jethrokuan/fzf

#fuzzy search
function fh
    history | fzf | read -l cmd
    if test -n "$cmd"
        eval $cmd
    end
end

function extract
    if test -f $argv[1]
        switch $argv[1]
            case '*.tar.gz' '*.tgz'
                tar xzf $argv[1]
            case '*.tar.bz2' '*.tbz2'
                tar xjf $argv[1]
            case '*.tar.xz' '*.txz'
                tar xJf $argv[1]
            case '*.zip'
                unzip $argv[1]
            case '*.rar'
                unrar x $argv[1]
            case '*'
                echo "Cannot extract '$argv[1]'"
        end
    else
        echo "'$argv[1]' is not a valid file"
    end
end

fish_vi_key_bindings   # vi 模式

set -gx export HTTP_PROXY="http:127.0.0.1:7897"
set -gx export HTTPS_PROXY="http:127.0.0.1:7897"
set -gx export http_proxy="http:127.0.0.1:7897"
set -gx export https_proxy="http:127.0.0.1:7897"

