local k = require("utils/keys")
local wezterm = require("wezterm")
local act = wezterm.action
local opacity = 1.0
require("utils/helpers")

wezterm.on("gui-startup", function(cmd) -- set startup Window position
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():set_position(1000, 1000)
end)

-- 低电量自动切换纯黑背景
wezterm.on("update-right-status", function(window, pane)
    local battery_info = wezterm.battery_info()
    if not battery_info or #battery_info == 0 then
        return  -- 无电池信息（台式机等）
    end

    local battery = battery_info[1]
    local charge = battery.state_of_charge  -- 0.0 ~ 1.0
    local state = battery.state  -- "Charging", "Discharging", "Empty", "Full", "Unknown"

    local LOW_THRESHOLD = 0.15  -- 15% 电量阈值
    if charge <= LOW_THRESHOLD and state == "Discharging" then
        window:set_config_overrides({
            colors = {
                background = "#000000",
                tab_bar = {
                    background = "#000000",
                },
            },
            window_background_opacity = 1.0,
        })
    else
        -- 恢复默认配置
        window:set_config_overrides({})
    end
end)

local config = {
    default_cursor_style = "BlinkingBar",
    -- 也可以选 "SteadyBar" （竖条但不闪烁）
    -- 其它可选项有：Block, BlinkingBlock, SteadyBlock, Underline, SteadyUnderline, BlinkingUnderline
    force_reverse_video_cursor = true,
    check_for_updates = true,
    font_size = 16,
    -- font = wezterm.font("JetBrains MonoNL Font Mono", { weight = "Regular" }),
    -- font = wezterm.font("Hack Nerd Font", { weight = "Regular" }),
    font = wezterm.font_with_fallback({
        { family = "JetBrains Mono", weight = "Medium" },
        "Noto Sans Mono CJK SC",  -- 中文 fallback
    }),
    line_height = 1.1,
    -- COLOR SCHEME
    color_scheme = "Catppuccin Mocha",
    set_environment_variables = {
        BAT_THEME = "Catppuccin-mocha",
    },
    -- WINDOW
    initial_cols = 127,
    initial_rows = 37,
    window_padding = {
        left = 15,
        right = 15,
        top = 15,
        bottom = 15,
    },
    adjust_window_size_when_changing_font_size = false,
    window_close_confirmation = "AlwaysPrompt",
    window_decorations = "RESIZE",
    window_background_opacity = opacity,
    -- TABS
    enable_tab_bar = true,
    use_fancy_tab_bar = false,
    hide_tab_bar_if_only_one_tab = true,
    show_new_tab_button_in_tab_bar = false,
    colors = {
        tab_bar = {
            background = "rgba(12%, 12%, 18%, 90%)",
            active_tab = {
                bg_color = "#cba6f7",
                fg_color = "rgba(12%, 12%, 18%, 0%)",
                intensity = "Bold",
            },
            inactive_tab = {
                fg_color = "#cba6f7",
                bg_color = "rgba(12%, 12%, 18%, 90%)",
                intensity = "Normal",
            },
            inactive_tab_hover = {
                fg_color = "#cba6f7",
                bg_color = "rgba(27%, 28%, 35%, 90%)",
                intensity = "Bold",
            },
            new_tab = {
                fg_color = "#808080",
                bg_color = "#1e1e2e",
            },
        },
    },
    keys =
    {
        { key = "F10", mods = "NONE", action = act.TogglePaneZoomState },
        { key = "F11", mods = "NONE", action = act.ToggleFullScreen },
        { key = "q", mods = "CTRL", action = act.CloseCurrentTab({ confirm = false }) },
        { key = "PageUp", mods = "CTRL", action = act.ActivateTabRelative(-1) },
        { key = "PageDown", mods = "CTRL", action = act.ActivateTabRelative(1) },
        { key = "1", mods = "ALT", action = act.ActivateTab(0) },
        { key = "2", mods = "ALT", action = act.ActivateTab(1) },
        { key = "3", mods = "ALT", action = act.ActivateTab(2) },
        { key = "4", mods = "ALT", action = act.ActivateTab(3) },
        { key = "5", mods = "ALT", action = act.ActivateTab(4) },
        { key = "6", mods = "ALT", action = act.ActivateTab(5) },
        { key = "7", mods = "ALT", action = act.ActivateTab(6) },
        { key = "8", mods = "ALT", action = act.ActivateTab(7) },
        { key = "9", mods = "ALT", action = act.ActivateTab(8) },

        -- WezTerm 原生分屏快捷键
        { key = "/", mods = "CTRL", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) }, -- 上下分屏
        { key = "2", mods = "CTRL", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) }, -- 左右分屏
        { key = "h", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Left") }, -- 切换到左侧 pane
        { key = "l", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Right") }, -- 切换到右侧 pane
        { key = "k", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Up") }, -- 切换到上方 pane
        { key = "j", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Down") }, -- 切换到下方 pane
        { key = "x", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) }, -- 关闭当前 pane
        -- 切换窗口透明度
        { key = "t", mods = "CTRL|ALT", action = wezterm.action.EmitEvent("toggle-opacity") },
    }
}

return config
