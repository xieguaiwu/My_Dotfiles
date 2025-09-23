local k = require("utils/keys")
local wezterm = require("wezterm")
local act = wezterm.action
local opacity = 1.0
local config = {}
require("utils/helpers")

wezterm.on("gui-startup", function(cmd) -- set startup Window position
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():set_position(1000, 1000)
end)

local config = {
    default_cursor_style = "BlinkingBar",
    -- 也可以选 "SteadyBar" （竖条但不闪烁）
    -- 其它可选项有：Block, BlinkingBlock, SteadyBlock, Underline, SteadyUnderline, BlinkingUnderline
    force_reverse_video_cursor = true,
    check_for_updates = true,
    font_size = 15,
    -- font = wezterm.font("JetBrains MonoNL Font Mono", { weight = "Regular" }),
    -- font = wezterm.font("Hack Nerd Font", { weight = "Regular" }),
    font = wezterm.font_with_fallback({
        -- { family = "FiraCode Nerd Font Mono", weight = "Regular" },
        -- { family = "Hack Nerd Font", weight = "Regular" },
        -- { family = "MesloLGL Nerd Font Mono", weight = "Regular" },
        { family = "JetBrains Mono", weight = "Medium" },
        -- { family = "Sarasa Term SC Nerd", weight = "Regular" },
        -- { family = "SF Pro", weight = "Regular" },
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

        k.cmd_to_tmux_prefix("n", '"'), -- tmux horizontal split
        k.cmd_to_tmux_prefix("N", "%"), -- tmux vertical split
        k.cmd_to_tmux_prefix("d", "w"), -- tmux-sessionx
        k.cmd_to_tmux_prefix("t", "c"), -- new tmux window
        k.cmd_to_tmux_prefix("w", "x"), -- tmux close pane
        k.cmd_to_tmux_prefix("z", "z"), -- tmux zoom
        {
            key = "t",
            mods = "CMD|CTRL",
            action = wezterm.action.EmitEvent("toggle-opacity"),
        },
    }
}

return config
