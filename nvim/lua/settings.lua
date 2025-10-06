-- ~/.config/nvim/lua/settings.lua

local opt = vim.opt

-- Appearance
opt.syntax = "on"
opt.number = true
opt.relativenumber = true
opt.showmatch = true
opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undodir" 
opt.termguicolors = true
opt.cursorcolumn = true

-- Indentation
opt.expandtab = true
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.encoding = "utf-8"

-- Technical
opt.ttimeout = true
opt.timeoutlen = 300
--opt.noreadonly = true
opt.completeopt = {"menu,menuone,noselect"}

-- Usage
opt.autoindent = true
opt.autoread = true
opt.ruler = true
opt.smartcase = true
opt.ignorecase = true
opt.splitright = true
opt.splitbelow = true
opt.wildmenu = true
opt.hidden = true

-- Clipboard
opt.clipboard = "unnamedplus,unnamed"

-- Cursor Style
vim.o.guicursor = "n:block,v:block,i:ver25,r:ver25,a:blinkon250-blinkoff100"
