if not status is-interactive
    return
end

# API keys (for OpenCode + pi-agent) — replace with your own keys
set -gx OPENCODE_API_KEY "<your-key>"
#xieguaiwu: "<your-key>"
#songjieshi: set -gx OPENCODE_API_KEY "<your-key>"
set -gx DEEPSEEK_API_KEY "<your-key>"
# QWEN Token Plan (订阅, token-plan.*.maas): 2026-08-29 实测 cn-beijing 200，key 按区域绑定只能用北京端点
# pi 的 qwen provider 用这个 (baseUrl=token-plan.cn-beijing...)
set -gx QWEN_API_KEY "<your-key>"
# QWEN PAYG (按量, dashscope.aliyuncs.com/compatible-mode): bl 翻译走这条 (见 ~/.config/bl/config.json provider qwen)
set -gx QWEN_PAYG_API_KEY "<your-key>"
set -gx NVIDIA_API_KEY "<your-key>"
set -gx MODELSCOPE_API_KEY "<your-key>"
set -gx VOLCENGINE_API_KEY "<your-key>"
set -gx OPENROUTER_API_KEY "<your-key>"
set -gx ZHIPUAI_API_KEY "<your-key>"
set -gx KIMI_API_KEY "<your-key>"

tirith init
/usr/bin/starship init fish --print-full-init | source

if not contains /usr/local/bin $PATH
    set -gx PATH /usr/local/bin $PATH
end
if not contains $HOME/.local/bin $PATH
    set -gx PATH $HOME/.local/bin $PATH
end
if not contains $HOME/.cargo/bin $PATH
    set -gx PATH $HOME/.cargo/bin $PATH
end
if not contains $HOME/.npm-global/bin $PATH
    set -gx PATH $HOME/.npm-global/bin $PATH
end

# 默认编辑器
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx DOOMWADPATH /home/xieguiawu/doom

# Node.js 内存上限 3GB — 防止 pi agent OOM 崩溃
set -gx NODE_OPTIONS "--max-old-space-size=3072"

# ==== 常用别名 ====
alias ll='ls -lh'
alias la='ls -lha'
alias lsl='lsd --long --human-readable --all'
alias lst='lsd --tree'
alias lsa='lsd -a'
alias ..='cd ..'
alias ...='cd ../..'
alias vi='nvim'

# Git 常用
alias lg='lazygit'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

alias update='sudo dnf update -y'
alias install='sudo dnf install -y'
alias remove='sudo dnf remove -y'
alias ggb='flatpak run org.geogebra.GeoGebra'
alias powersave='sudo cpupower frequency-set -g powersave'
alias performance='sudo cpupower frequency-set -g performance'
alias cpufreq='cpupower frequency-info'
alias od='opencode'
alias ds='deepseek'

#bl — 词典翻译 & 语法解析
alias fgerman='bl --llm --from-lang German --to-lang English'
alias tgerman='bl --llm --pick --to-lang German'
alias fenglish='bl --llm --from-lang English'
alias tenglish='bl --llm --pick --to-lang English'
alias tfrench='bl --llm --pick --to-lang French'
alias ffrench='bl --llm --from-lang French --to-lang English'
alias fchinese='bl --cn'

# Parse 变体: 在别名后加 -p 即进入语法解析模式
# 例: fgerman-p "Der Mann geht nach Hause."
alias fgerman-p='bl --llm --parse --from-lang German --to-lang English'
alias tgerman-p='bl --llm --parse --to-lang German'
alias fenglish-p='bl --llm --parse --from-lang English'
alias tenglish-p='bl --llm --parse --to-lang English'
alias ffrench-p='bl --llm --parse --from-lang French --to-lang English'

alias trash='gio trash'

# 智能语法解析: 输入含空格(句子) → 自动解析; 否则 → 普通翻译
# 例: fgerman? "Der Mann geht nach Hause."
function fgerman?
    if string match -qr '\s' -- $argv[1]
        bl --llm --parse --from-lang German --to-lang English $argv
    else
        bl --llm --from-lang German --to-lang English $argv
    end
end
function tenglish?
    if string match -qr '\s' -- $argv[1]
        bl --llm --parse --to-lang English $argv
    else
        bl --llm --pick --to-lang English $argv
    end
end

# ~/.config/fish/config.fish
function mkcd
    mkdir -p $argv
    cd $argv
end

# Git 快速分支切换
function gco
    git checkout $argv
end

#function fish_prompt
#    set_color cyan
#    echo -n (whoami)"@"(hostname) " "
#    set_color yellow
#    echo -n (prompt_pwd) " "
#    set_color green
#    echo -n (date "+%H:%M")" "
#    set_color magenta
#    echo -n "❯ "
#    set_color normal
#end

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

set -gx HTTP_PROXY http://127.0.0.1:7897
set -gx HTTPS_PROXY http://127.0.0.1:7897
set -gx http_proxy http://127.0.0.1:7897
set -gx https_proxy http://127.0.0.1:7897
# AGI Bar 店内 API 直连（2026-08-25 实测：小写优先，必须两个都设）
set -gx no_proxy "agi.bar,token.agi.bar,localhost,127.0.0.1,::1"
set -gx NO_PROXY "agi.bar,token.agi.bar,localhost,127.0.0.1,::1"
set -gx PUPPETEER_EXECUTABLE_PATH /home/xieguiawu/.cache/puppeteer/chrome/linux-149.0.7827.22/chrome-linux64/chrome
set -gx GOTOOLCHAIN auto
set -gx GOPATH $HOME/go
set -gx GOPROXY https://goproxy.cn,direct
if not contains $GOPATH/bin $PATH
    set -gx PATH $PATH $GOPATH/bin
end

set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin /home/xieguiawu/.ghcup/bin $PATH # ghcup-env

# ===== Pi Coding Agent =====
# Quick pi one-shot: pi "question"
function piq
    pi -p $argv
end
# Quick pi with resume
function pir
    pi --resume $argv
end
# Quick pi with continue
function pic
    pi --continue $argv
end
# Safe update: runs pi update then automatically reapplies local patches
function piu
    echo "→ Running pi update..."
    command pi update $argv
    set -l pi_exit $status
    if test $pi_exit -ne 0
        echo "⚠️  pi update failed (exit $pi_exit) — skipping reapply"
        return $pi_exit
    end
    echo ""
    echo "→ Reapplying local patches..."
    bash ~/.pi/patches/reapply.sh
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Steam proxy wrapper — from terminal

# ===== Pentest AI Toolkit =====
# ptai 使用 DeepSeek 作为 LLM 后端
set -gx PENTEST_AI_LLM_PROVIDER deepseek
set -gx PENTEST_AI_MODEL deepseek-chat

# PentestGPT (legacy) — 交互式会话，启动后在提示符下描述目标
# 例: "对 192.168.1.50 进行全端口扫描和漏洞发现"
alias pentest-deepseek='pentestgpt-legacy --reasoning-model deepseek-v4-flash --parsing-model deepseek-v4-flash --generation-model deepseek-v4-flash'
alias pentest-pro='pentestgpt-legacy --reasoning-model deepseek-v4-pro --parsing-model deepseek-v4-pro --generation-model deepseek-v4-pro'

# pentest-ai — 直接指定目标（推荐用于快速扫描）
# 用法: ptai-scan 192.168.1.50
alias ptai-scan='ptai start'
alias ptai-chain='ptai chain'

# bettercap (Go install path)
alias bettercap='$HOME/go/bin/bettercap'

# 快速进入工具目录
alias pentest-lab='cd $HOME/pentest-ai && ls -la'

# 一键扫描 + AI 分析
alias pentest-scan='$HOME/pentest-ai/scripts/scan-and-report.sh'

# MITM 实验室
alias pentest-mitm='$HOME/pentest-ai/scripts/mitm-lab.sh'

# Tavily Search API key (free tier, 1000 searches/month)
set -gx TAVILY_API_KEY "<your-key>"

# 和风天气 qw CLI (JWT 认证)
set -gx QWEATHER_KID "TMGTQTN2TJ"
set -gx QWEATHER_PROJECT_ID "2DKTPF8PGY"
set -gx QWEATHER_PRIVATE_KEY "$HOME/.config/qweather/ed25519-private.pem"
set -gx QWEATHER_BASE_URL "https://p56vhhm5yp.re.qweatherapi.com/v7"
set -gx QWEATHER_GEO_URL "https://p56vhhm5yp.re.qweatherapi.com/geo/v2"

# Bitwarden 取用：k <条目名> [rbw get 参数...]
# 例: k api/opencode | k server/racknerd --full | k api/x --field=notes
function k
    if test (count $argv) -eq 0
        echo "用法: k <条目名> [rbw get 参数...]"
        return 1
    end
    rbw get $argv
end
