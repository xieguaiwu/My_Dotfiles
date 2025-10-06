-- ~/.config/nvim/lua/keymaps.lua

local map = vim.keymap.set

-- quick replacing
map("n", "<C-h>", ":%s///g<Left><Left><CR>", { desc = "Quick Replace" })

-- move lines up and down
map("n", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
map("n", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- muti-window
map("n", "sl", ":set splitright<CR>:vsplit<CR>", { desc = "Vertical Split Right" })
map("n", "sh", ":set nosplitright<CR>:vsplit<CR>", { desc = "Vertical Split Left" })
map("n", "sk", ":set nosplitbelow<CR>:split<CR>", { desc = "Horizontal Split Up" })
map("n", "sj", ":set splitbelow<CR>:split<CR>", { desc = "Horizontal Split Down" })

-- for tab pages in vim
map("n", "<C-t>", ":tabnew<CR>", { desc = "New Tab" })
map("n", "<C-l>", ":tabnext<CR>", { desc = "Next Tab" })

local utils = require("utils")

-- 编译/运行
map("n", "<C-A-b>", utils.CompileRun, { desc = "Compile and Run File" })

