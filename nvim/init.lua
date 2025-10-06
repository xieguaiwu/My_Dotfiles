-- ~/.config/nvim/init.lua

vim.g.coc_path = vim.fn.exepath('node')

require("settings")
require("utils")
require("keymaps")

-- loading lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- 推荐使用 stable 分支
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
    --configure lazy.nvim
    checker = { enabled = true, notify = false }, -- 启动后自动检查更新
    performance = {
        rtp = {
            -- 禁用可能影响启动速度的默认插件
            disabled_plugins = {
                "gzip",
                "tarPlugin",
                "tohtml",
                "tutor",
                "zipPlugin",
            },
        },
    },
})
