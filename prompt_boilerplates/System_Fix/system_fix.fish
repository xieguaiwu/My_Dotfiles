#!/usr/bin/env fish
# system_fix.fish — 系统健康检查 + 智能清理引导
#
# 用法:
#   source system_fix.fish          # 交互式执行
#   source system_fix.fish --dry    # 只检查，不执行任何操作
#   source system_fix.fish --auto   # 跳过确认，执行所有安全清理
#
# 功能:
#   1. Core dump 诊断
#   2. 缓存/垃圾文件分析 + 引导清理
#   3. DNF 速度诊断 + 国内镜像引导切换
#   4. 崩溃频率告警

set -l SCRIPT_VERSION "1.0.0"

# ============================================================
# 辅助函数
# ============================================================

function _info -a msg
    set_color cyan
    echo "ℹ️  $msg"
    set_color normal
end

function _ok -a msg
    set_color green
    echo "✅ $msg"
    set_color normal
end

function _warn -a msg
    set_color yellow
    echo "⚠️  $msg"
    set_color normal
end

function _err -a msg
    set_color red
    echo "❌ $msg"
    set_color normal
end

function _section -a title
    echo ""
    set_color --bold blue
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    set_color normal
end

function _prompt -a msg
    if test $_flag_auto -eq 1
        return 0
    end
    if test $_flag_dry -eq 1
        return 1
    end
    echo ""
    set_color yellow
    echo "→ $msg [y/N] "
    set_color normal
    read -l response
    or set response "n"
    # string match is sensitive to $ placement, use explicit test
    echo "$response" | grep -qiE '^y|yes$' >/dev/null 2>&1
end

function _hr
    echo "────────────────────────────────────────────"
end

# ============================================================
# 模块 1: Core Dump 诊断
# ============================================================

function check_core_dump
    _section "🧠 Core Dump 诊断"

    # 检查配置
    set -l core_limit (ulimit -c 2>/dev/null)
    set -l core_pattern (cat /proc/sys/kernel/core_pattern 2>/dev/null)
    echo "  ulimit -c:          $core_limit"
    echo "  core_pattern:       $core_pattern"

    # 检查已存储的 core dump
    set -l coredump_dir /var/lib/systemd/coredump
    if test -d $coredump_dir
        set -l coredump_count (ls $coredump_dir 2>/dev/null | wc -l)
        set -l coredump_size (du -sh $coredump_dir 2>/dev/null | awk '{print $1}')
        if test $coredump_count -eq 0
            _ok "core dump 目录为空，已占用 0 空间"
        else
            _warn "发现 $coredump_count 个 core dump 文件，占用 $coredump_size"
            if _prompt "删除所有 core dump 文件？"
                sudo rm -f $coredump_dir/*
                _ok "已清理"
            end
        end
    else
        _info "core dump 目录不存在 (systemd-coredump 未启用)"
    end

    # 检查崩溃历史
    if command -q coredumpctl
        set -l crash_list (coredumpctl list 2>/dev/null)
        if test -n "$crash_list"
            set -l crash_count (echo "$crash_list" | tail -n +2 | wc -l)
            # 按 EXE 统计
            echo ""
            echo "  崩溃记录（最近 2 周共 $crash_count 次）:"
            echo "$crash_list" | tail -n +2 | awk '{print $7}' | sort | uniq -c | sort -rn \
                | while read -l count exe
                    set -l short_exe (basename $exe 2>/dev/null; or echo $exe)
                    if test $count -ge 10
                        _warn "  $count 次  $short_exe ★ 高频"
                    else
                        echo "    $count 次  $short_exe"
                    end
                  end

            # 高频崩溃告警
            set -l top_crash (echo "$crash_list" | tail -n +2 | awk '{print $7}' | sort | uniq -c | sort -rn | head -1)
            if test -n "$top_crash"
                set -l top_count (echo $top_crash | awk '{print $1}')
                set -l top_exe (echo $top_crash | awk '{print $2}')
                if test $top_count -ge 10
                    echo ""
                    _warn "★ $top_exe 崩溃 $top_count 次，值得关注"
                    if string match -q "*node*" $top_exe
                        echo "   常见原因：pi-agent / coc.nvim / language server 插件冲突"
                        echo "   建议：检查 ~/.pi/agent/logs/ 和 coc.nvim 插件更新"
                    end
                end
            end
        else
            _ok "未发现崩溃记录"
        end
    else
        _info "coredumpctl 未安装，跳过崩溃历史检查"
    end
    _hr
end

# ============================================================
# 模块 2: 缓存/垃圾文件分析
# ============================================================

function check_cache
    _section "🗑️  系统缓存与垃圾文件"

    # --- 旧内核 ---
    echo "  ① 旧内核"
    set -l current_kernel (uname -r)
    set -l installed_kernels (rpm -q kernel 2>/dev/null | sort)
    set -l kernel_count (echo "$installed_kernels" | wc -l)
    set -l removable_kernels (rpm -q kernel 2>/dev/null | grep -v (echo $current_kernel | sed 's/-[^-]*$//'))

    echo "    当前: $current_kernel"
    echo "    已安装: $kernel_count 个"
    if test (count $removable_kernels) -gt 0
        for k in $removable_kernels
            _warn "    可移除: $k"
        end
        if _prompt "删除旧内核？"
            for k in $removable_kernels
                sudo dnf remove -y $k 2>/dev/null
                _ok "已删除 $k"
            end
        end
    else
        _ok "无旧内核需要清理"
    end

    # --- 缓存占用分析 ---
    echo ""
    echo "  ② 用户缓存占用"

    # 缓存列表: 路径 描述 危险性(safe/caution)
    set -l caches
    set caches $caches "$HOME/.cache/pip\tpip (Python 包缓存)\tsafe"
    set caches $caches "$HOME/.cache/uv\tuv (Python 包缓存)\tsafe"
    set caches $caches "$HOME/.cache/bun\tbun (JS 运行时缓存)\tsafe"
    set caches $caches "$HOME/.npm\tnpm (Node 包缓存)\tsafe"
    set caches $caches "$HOME/.cache/opencode\tOpenCode AI 缓存\tsafe"
    set caches $caches "$HOME/.cache/huggingface\thuggingface 模型缓存\tcaution"
    set caches $caches "$HOME/.cache/ms-playwright\tPlaywright 浏览器\tcaution"
    set caches $caches "$HOME/.cache/puppeteer\tPuppeteer 浏览器\tcaution"
    set caches $caches "$HOME/.cache/mathlib\tmathlib 缓存\tsafe"
    set caches $caches "$HOME/.local/share/Trash\t回收站\tsafe"

    for entry in $caches
        set -l parts (string split \t $entry)
        set -l path $parts[1]
        set -l desc $parts[2]
        set -l risk $parts[3]

        if test -e $path
            set -l size (du -sh $path 2>/dev/null | awk '{print $1}')
            set -l size_bytes (du -sb $path 2>/dev/null | awk '{print $1}')

            # 只显示 > 10MB 的
            if test $size_bytes -gt 10485760
                if test "$risk" = "caution"
                    _warn "  $desc: $size （谨慎清理）"
                else
                    echo "    $desc: $size"
                end
            end
        end
    end

    # --- 缓存总计 ---
    echo ""
    echo "  ③ 缓存总计"
    set -l total_size (
        du -sb \
            $HOME/.cache/pip \
            $HOME/.cache/uv \
            $HOME/.cache/bun \
            $HOME/.npm \
            $HOME/.cache/opencode \
            $HOME/.cache/mathlib \
            $HOME/.local/share/Trash \
            2>/dev/null | awk '{s+=$1} END {printf "%.1f", s/1024/1024/1024}'
    )
    echo "    安全可清理: ~$total_size GB"

    if _prompt "执行安全缓存清理？（pip/uv/bun/npm/opencode/mathlib/回收站）"
        # pip
        if command -q pip
            pip cache purge 2>/dev/null; and _ok "pip 缓存已清理"
        end
        # uv
        if command -q uv
            uv cache clean 2>/dev/null; and _ok "uv 缓存已清理"
        end
        # bun
        if command -q bun
            bun pm cache rm 2>/dev/null; and _ok "bun 缓存已清理"
        end
        # npm
        if command -q npm
            npm cache clean --force 2>/dev/null; and _ok "npm 缓存已清理"
        end
        # opencode
        if test -d $HOME/.cache/opencode
            rm -rf $HOME/.cache/opencode 2>/dev/null; and _ok "OpenCode 缓存已清理"
        end
        # mathlib
        if test -d $HOME/.cache/mathlib
            rm -rf $HOME/.cache/mathlib 2>/dev/null; and _ok "mathlib 缓存已清理"
        end
        # trash
        if test -d $HOME/.local/share/Trash
            rm -rf $HOME/.local/share/Trash/{files,info} 2>/dev/null; and _ok "回收站已清空"
        end
        _ok "安全缓存清理完成"
    else
        echo "    跳过"
    end

    # --- 日志文件 ---
    echo ""
    echo "  ④ 系统日志"
    # journal 占用
    if command -q journalctl
        set -l journal_size (journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+(G|M|B)')
        echo "    journal 日志: $journal_size"
        if _prompt "压缩 journal 日志至最近 7 天？"
            sudo journalctl --vacuum-time=7d 2>/dev/null
            _ok "journal 已压缩"
        end
    end

    # 旧 /var/log/messages
    set -l old_logs (find /var/log -name 'messages-*' -size +10M 2>/dev/null)
    if test -n "$old_logs"
        set -l log_total (du -ch /var/log/messages-* 2>/dev/null | tail -1 | awk '{print $1}')
        echo "    旧日志归档: $log_total"
        if _prompt "删除旧日志归档？"
            sudo rm -f /var/log/messages-*
            _ok "旧日志已删除"
        end
    else
        _ok "无旧日志归档"
    end

    _hr
end

# ============================================================
# 模块 3: DNF 速度诊断
# ============================================================

function check_dnf
    _section "🐌 DNF 下载速度诊断"

    # 检查配置
    echo "  dnf.conf 配置:"
    if grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null
        _ok "  max_parallel_downloads 已设置"
    else
        _warn "  max_parallel_downloads 未设置（默认 3，建议 10）"
    end
    if grep -q "fastestmirror" /etc/dnf/dnf.conf 2>/dev/null
        _ok "  fastestmirror 已启用"
    else
        _warn "  fastestmirror 未启用"
    end

    # 检查各 repo 源
    echo ""
    echo "  源位置分析:"

    # 检查 Fedora 主源
    if grep -q "tuna\|aliyun\|ustc\|huawei" /etc/yum.repos.d/fedora.repo 2>/dev/null
        _ok "  Fedora 主源 → 国内镜像 ✓"
    else
        _warn "  Fedora 主源 → 可能走海外 metalink"
    end

    if grep -q "tuna\|aliyun\|ustc\|huawei" /etc/yum.repos.d/fedora-updates.repo 2>/dev/null
        _ok "  Fedora Updates → 国内镜像 ✓"
    else
        _warn "  Fedora Updates → 可能走海外 metalink"
    end

    # 检查 RPM Fusion
    set -l rpmfusion_files /etc/yum.repos.d/rpmfusion-free-updates.repo /etc/yum.repos.d/rpmfusion-free-updates-testing.repo /etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo
    for f in $rpmfusion_files
        if test -f $f
            if grep -q "tuna\|aliyun\|ustc\|huawei" $f 2>/dev/null
                _ok "  "(basename $f)" → 国内镜像 ✓"
            else if grep -q "^metalink" $f 2>/dev/null
                _warn "  "(basename $f)" → 海外 metalink，需切换"
            end
        end
    end

    # 检查 COPR 源
    set -l copr_count 0
    for f in /etc/yum.repos.d/_copr*.repo
        if test -f $f
            set copr_count (math $copr_count + 1)
        end
    end
    if test $copr_count -gt 0
        _warn "  已启用 $copr_count 个 COPR 源（全部在 copr.fedorainfracloud.org 海外）"
    end

    # 测速
    echo ""
    echo "  网络测速:"
    # 测国内镜像
    set -l tuna_speed (curl -s -o /dev/null -w '%{speed_download}' --max-time 10 \
        "https://mirrors.tuna.tsinghua.edu.cn/fedora/updates/42/Everything/x86_64/repodata/repomd.xml" 2>/dev/null)
    if test -n "$tuna_speed"
        set -l tuna_kbps (math -s0 "$tuna_speed / 1024")
        echo "    TUNA 清华: $tuna_kbps KiB/s"
    end
    # 测整体带宽
    set -l bw_speed (curl -s -o /dev/null -w '%{speed_download}' --max-time 15 \
        "https://speed.cloudflare.com/__down?bytes=10485760" 2>/dev/null)
    if test -n "$bw_speed"
        set -l bw_mbps (math -s1 "$bw_speed / 1048576")
        echo "    Cloudflare: $bw_mbps MB/s（总带宽）"
        if test "$bw_mbps" -lt 2
            _warn "    总带宽偏低，可能是网络本身问题"
        else
            _ok "    总带宽正常，问题在镜像源选择"
        end
    end

    # 修复建议/执行
    echo ""
    set -l need_fix 0
    if not grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null
        set need_fix 1
    end
    for f in /etc/yum.repos.d/rpmfusion-free-updates.repo /etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo
        if test -f $f
            if not grep -q "tuna\|aliyun" $f 2>/dev/null
                set need_fix 1
            end
        end
    end

    if test $need_fix -eq 1
        echo "  诊断结论: 需要修复以下问题:"
        if not grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null
            _warn "  · dnf.conf 缺少 max_parallel_downloads"
        end
        if not grep -q "fastestmirror" /etc/dnf/dnf.conf 2>/dev/null
            _warn "  · dnf.conf 缺少 fastestmirror"
        end
        for f in /etc/yum.repos.d/rpmfusion-free-updates.repo /etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo
            if test -f $f
                if not grep -q "tuna\|aliyun" $f 2>/dev/null
                    _warn "  · "(basename $f)" 需切换国内镜像"
                end
            end
        end
        if test $copr_count -gt 0
            _warn "  · $copr_count 个 COPR 源在海外，可手动切换："
            echo "      sudo sed -i 's|copr.fedorainfracloud.org|mirrors.tuna.tsinghua.edu.cn/copr|' /etc/yum.repos.d/_copr*.repo"
        end

        if _prompt "执行 DNF 修复？（dnf.conf 优化 + RPM Fusion 切换国内镜像）"
            echo ""

            # dnf.conf
            if not grep -q "max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null
                echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf >/dev/null
                _ok "  max_parallel_downloads=10 已添加"
            end
            if not grep -q "fastestmirror" /etc/dnf/dnf.conf 2>/dev/null
                echo 'fastestmirror=True' | sudo tee -a /etc/dnf/dnf.conf >/dev/null
                _ok "  fastestmirror=True 已启用"
            end

            # RPM Fusion → TUNA
            for repo in /etc/yum.repos.d/rpmfusion-free-updates.repo /etc/yum.repos.d/rpmfusion-free-updates-testing.repo /etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo
                if test -f $repo
                    sudo sed -i 's|^metalink=https://mirrors.rpmfusion.org|#metalink=https://mirrors.rpmfusion.org|' $repo 2>/dev/null
                    sudo sed -i 's|^#baseurl=http://download1.rpmfusion.org|baseurl=https://mirrors.tuna.tsinghua.edu.cn/rpmfusion|' $repo 2>/dev/null
                    _ok "  "(basename $repo)" 已切换"
                end
            end

            # 清除旧缓存
            sudo dnf clean all 2>/dev/null
            _ok "  DNF 缓存已清空"

            echo ""
            _ok "DNF 修复完成！下次 dnf update 应该会快很多"
            echo "  验证: dnf check-update"
        end
    else
        _ok "DNF 配置正常"
    end
    _hr
end

# ============================================================
# 模块 4: 资源占用概览
# ============================================================

function check_resources
    _section "📊 系统资源概览"

    # 磁盘
    echo "  磁盘使用:"
    df -h / 2>/dev/null | tail -n +2 | awk '{printf "    %s: 已用 %s / 共 %s (%s)\n", $1, $3, $2, $5}' 2>/dev/null; or echo '    (df 不可用)'

    # 内存
    echo ""
    echo "  内存:"
    free -h 2>/dev/null | grep -E "Mem|Swap" | while read -l line
        set -l parts (string split -n " " $line)
        # parts[1] already has colon (e.g. "Mem:")
        set -l label (string trim -c ':' $parts[1])
        echo "    $label: 已用 $parts[3] / 共 $parts[2]"
    end

    # 大目录 TOP10
    echo ""
    echo "  \$HOME 大目录 TOP10:"
    du -sh $HOME/*/ 2>/dev/null | sort -rh | head -10 \
        | while read -l line
            echo "    $line"
          end

    _hr
end

# ============================================================
# 主流程（直接在全局运行，避免 function end 嵌套问题）
# ============================================================

# 参数解析
set -g _flag_dry 0
set -g _flag_auto 0

for arg in $argv
    switch $arg
        case --dry
            set -g _flag_dry 1
        case --auto
            set -g _flag_auto 1
    end
end

echo ""
set_color --bold magenta
echo " ╔══════════════════════════════════════════╗"
echo " ║   🛠️  System Fix v$SCRIPT_VERSION            ║"
echo " ║   系统健康检查 + 智能清理引导             ║"
echo " ╚══════════════════════════════════════════╝"
set_color normal
echo "  运行时间: "(date "+%Y-%m-%d %H:%M:%S")
if test $_flag_dry -eq 1
    echo "  模式: --dry（仅检查，不执行操作）"
else
    echo "  模式: 交互式（操作前会询问确认）"
end

check_core_dump
check_cache
check_dnf
check_resources

# 汇总
_section "📋 汇总"
_ok "诊断完成"
if test $_flag_dry -eq 1
    echo "  本次为 --dry（仅检查）模式，未执行任何操作"
    echo "  直接运行脚本进入交互模式: source system_fix.fish"
else
    echo "  部分清理可能需 sudo 权限"
    echo "  若 dnf 仍有问题，可尝试: dnf clean all && dnf makecache"
end
echo ""
