if status is-interactive
    # Commands to run in interactive sessions can go here
end

# ~/.config/fish/config.fish

# 设置 PATH（确保不重复）
if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end

# 设置默认编辑器
set -gx EDITOR vim
set -gx VISUAL vim

# 常用别名
alias ll='ls -lh'
alias la='ls -lha'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

alias update='sudo dnf update -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'

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

fish_vi_key_bindings

# 开启自动建议（如果安装了插件）
# fisher install jethrokuan/z
# fisher install jethrokuan/fzf
# ~/.config/fish/config.fish

# ==== 基础环境 ====
# 确保 PATH 干净且包含常用路径
if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end
if not contains $HOME/.local/bin $PATH
    set -gx PATH $HOME/.local/bin $PATH
end

# 默认编辑器
set -gx EDITOR nvim
set -gx VISUAL nvim

# ==== 常用别名 ====
alias ll='ls -lh'
alias la='ls -lha'
alias ..='cd ..'
alias ...='cd ../..'

# Git 常用
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# 系统常用
alias update='sudo dnf update -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'

function mkcd
    mkdir -p $argv
    cd $argv
end

# 快速搜索命令历史（模糊匹配）
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

fish_vi_key_bindings   # vi 模式（实用，命令行编辑更方便）
