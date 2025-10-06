-- ~/.config/nvim/lua/plugins/init.lua

return {
    -- 1. Mason
    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        lazy = false,
        priority = 1000,
        config = true
    },

    -- 2. 颜色主题 (高优先级)
    {
        "erichdongubler/vim-sublime-monokai",
        lazy = false,
        priority = 999,
	config = function()
			vim.cmd("colorscheme sublimemonokai")
	end
    },

    -- 3. Lualine
    {
        "nvim-lualine/lualine.nvim",
        lazy = false,
        opts = {
            options = { theme = "nord" },
        },
    },

    -- 4. LSP config
    {
        "neovim/nvim-lspconfig",
        lazy = false, -- <--- 关键修正：确保API在config前初始化
        dependencies = { "williamboman/mason-lspconfig.nvim" },
        config = function()
            require("lsp.init")
        end,
    },
    {
        "neoclide/coc.nvim",
        branch = {release},
        lazy = false,            -- 必须强制加载，否则无法工作
        config = function()
            local map = vim.keymap.set
            local opts = { silent = true, noremap = true }

            map('n', 'gd', '<Plug>(coc-definition)', opts)       -- 定义
            map('n', 'gy', '<Plug>(coc-type-definition)', opts)  -- 类型定义
            map('n', 'gi', '<Plug>(coc-implementation)', opts)   -- 实现
            map('n', 'gr', '<Plug>(coc-references)', opts)       -- 引用

            map('i', '<A-z>', 'coc#refresh()', { silent = true, expr = true, noremap = true })
            
            -- 3. 复杂 Tab 键逻辑和函数 (必须使用 vim.cmd 注入 Vimscript)
            -- Tab 键的逻辑包含了检查退格、代码片段跳转、补全选择等，很难用纯 Lua 完美重写。
            vim.cmd([[
                function! s:check_back_space() abort
                  let col = col('.') - 1
                  return !col || getline('.')[col - 1] =~# '\s'
                endfunc

                " Tab/Shift-Tab 补全逻辑
                inoremap <silent><expr> <TAB>
                      \ pumvisible() ? "\<C-n>" :
                      \ <SID>check_back_space() ? "\<TAB>" :
                      \ coc#refresh()
                inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
            ]])
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = {
                    "c", "cpp", "lua", "vim", "vimdoc", "markdown", "rust",
                    "go", "python", "java",
                    --"sh"
                },
                highlight = { enable = true },
                indent = { enable = true },
            })
        end,
    },
    -- nvim-cmp
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp", -- LSP 源
            "hrsh7th/cmp-buffer",   -- Buffer 源
            "hrsh7th/cmp-path",     -- Path 源
            "L3MON4D3/LuaSnip",     -- Snippet 引擎
            "saadparwaiz1/cmp_luasnip", -- Snippet 源
        },
        config = function()
            require("cmp.init") -- 另建文件配置 cmp 映射和行为
        end,
    },
    -- Snippets
    {
        "L3MON4D3/LuaSnip",
        dependencies = { "rafamadriz/friendly-snippets" },
        build = "make install_jsregexp",
    },
    -- 文件树
    {
        "nvim-tree/nvim-tree.lua",
        cmd = { "NvimTreeToggle", "NvimTreeFocus" },
        keys = { { "<C-e>", ":NvimTreeToggle<CR>", desc = "Toggle NvimTree" } }, -- <C-e> mapping to toggle
        config = function()
            require("nvim-tree").setup({})
        end,
    },
    -- fuzzy Search
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "Telescope",
        keys = {
            -- quick toggle by <C-p>
            { "<C-p>", function() require('telescope.builtin').git_files() end, desc = "Git Files (Telescope)" },
        },
        config = function()
            require("telescope").setup({})
        end,
    },
    -- Git 集成
    { "lewis6991/gitsigns.nvim", event = "BufReadPost" },
    -- Auto-pairs
    { "windwp/nvim-autopairs", event = "InsertEnter", config = true },
    -- Indent Lines
    { "lukas-reineke/indent-blankline.nvim", event = "BufReadPost", main = "ibl", opts = {} },
    -- 格式化
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        config = function()
            require("conform").setup({
                formatters = {
                    astyle = {
                        args = {
                            "--mode=c",
                            "--style=java",
                            "--indent=tab",
                            "--pad-oper",
                            "--pad-header",
                            "--unpad-paren",
                            "--suffix=none",
                            "$FILE",
                        },
                        require_cmd = true,
                    },
                },
                formatters_by_ft = {
                    c = { "astyle" },
                    cpp = { "astyle" },
                    rust = { "rustfmt" },
                    python = { "black" },
                    java = { "google-java-format" },
                },
            })
            vim.keymap.set({ "n", "v" }, "<leader>g", function()
                require("conform").format()
            end, { desc = "Format File (Conform)"})
        end,
    },
    -- 异步 Linting
    {
        "mfussenegger/nvim-lint",
        event = "BufReadPost",
        config = function()
        end,
    },
    { "tpope/vim-unimpaired" },
    { "godlygeek/tabular", cmd = "Tabularize" },
    -- vim-workspace
    { "thaerkh/vim-workspace", config = function()
        vim.g.workspace_persist_undo_history = 1
        vim.g.workspace_undodir = vim.fn.stdpath("data") .. "/undodir"
        vim.g.workspace_autosave = 0
    end },
    -- vim-markdown
    { "plasticboy/vim-markdown", ft = "markdown", config = function()
        vim.g.vim_markdown_math = 1
        vim.g.vim_markdown_folding_disabled = 1
        vim.g.vim_markdown_strikethrough = 1
        vim.g.vim_markdown_new_list_items = 1
        vim.g.vim_markdown_borderless_table = 1
    end },
    { "fatih/vim-go", ft = "go" },
    { "rust-lang/rust.vim", ft = "rust" },
    -- vimtex
    { "lervag/vimtex", ft = "tex", config = function()
        vim.g.vimtex_view_method = 'zathura'
        vim.g.vimtex_compiler_method = 'latexmk'
        vim.g.vimtex_compiler_latexmk = {
            ['build_dir'] = '',
            ['options'] = {
                '-xelatex',
                '-file-line-error',
                '-interaction=nonstopmode',
                '-synctex=1',
            },
        }
    end },
    -- Lean Prover
    { "leanprover/lean.nvim", ft = "lean" },
    { "Julian/lean.nvim", ft = "lean" },
    -- Pinyin Search
    { "ppwwyyxx/vim-pinyinsearch", config = function()
        vim.g.PinyinSearch_Dict = vim.fn.stdpath("data") .. "/lazy/vim-pinyinsearch/PinyinSearch.dict"
        vim.keymap.set("n", "?", ":call PinyinSearch()<CR>", { desc = "Pinyin Search" })
        vim.keymap.set("n", "<leader>pn", ":call PinyinNext()<CR>", { desc = "Pinyin Next" })
    end },
}
