-- ~/.config/nvim/lua/keymaps.lua

local map = vim.keymap.set

-- jump from lines
map("n", "j", "gj")
map("n", "k", "gk")

-- copy to system clipboard
map("n", "9y", "\"+y")

-- quick replacing
map("n", "<C-h>", ":%s//g<Left><Left>", { noremap = true, silent = false, desc = "Quick Replace" })

-- move lines up and down
map("n", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("n", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- muti-window
map("n", "fl", ":set splitright<CR>:vsplit<CR>", { desc = "Vertical Split Right" })
map("n", "fh", ":set nosplitright<CR>:vsplit<CR>", { desc = "Vertical Split Left" })
map("n", "fk", ":set nosplitbelow<CR>:split<CR>", { desc = "Horizontal Split Up" })
map("n", "fj", ":set splitbelow<CR>:split<CR>", { desc = "Horizontal Split Down" })

-- for tab pages in vim
map("n", "<A-t>", ":tabnew<CR>", { desc = "New Tab" })
map("n", "<C-l>", ":tabnext<CR>", { desc = "Next Tab" })
map("n", "<C-k>", ":tabprevious<CR>", { desc = "Previous Tab" })

local utils = require("utils")

-- 编译/运行
map("n", "<C-A-b>", utils.CompileRun, { desc = "Compile and Run File" })
map("n", "<C-A-f>", utils.SelfFormat, { desc = "Formatting the File" })
