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
        branch = "release",      -- 修复语法错误：从 {release} 改为 "release"
        lazy = false,            -- 必须强制加载
        config = function()
            vim.cmd([[
                inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
                inoremap <silent><expr> <CR>
                \ pumvisible() ? coc#pum#confirm() :
                \ coc#expandable() ? coc#rpc#request('do:expandSnippet') :
                \ "\<CR>"

                nmap <silent> gd <Plug>(coc-definition)
                nmap <silent> gy <Plug>(coc-type-definition)
                nmap <silent> gi <Plug>(coc-implementation)
                nmap <silent> gr <Plug>(coc-references)

                " 补全刷新
                inoremap <silent><expr> <A-z> coc#refresh()
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
        "vim-autoformat/vim-autoformat",
        cmd = "Autoformat", -- 保持不变
        -- **关键修改区域**
        config = function()
            local excluded_filetypes = {
                "c",
                "cpp",
                "java",
                "rust",
                --"sh",
            }
            -- 1. 定义 Lua 格式化函数，包含文件类型检查
            local function ConditionalAutoformat()
                local ft = vim.bo.filetype
                for _, excluded_ft in ipairs(excluded_filetypes) do
                    if ft == excluded_ft then
                        return
                    end
                end
                vim.cmd("Autoformat")
            end
            -- 2. 设置保存时自动运行该函数
            -- BufWritePre: 在缓冲区写入磁盘之前运行
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = vim.api.nvim_create_augroup("AutoformatGroup", { clear = true }),
                pattern = "*", -- 对所有文件生效
                callback = ConditionalAutoformat, -- 调用我们自定义的 Lua 函数
            })

            -- 3. 映射 <leader>f 到手动格式化命令 (保持不变)
            vim.keymap.set({"n", "v"}, "<C-A-f>", ":Autoformat<CR>", { desc = "Autoformat File" })
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
    -- { "fatih/vim-go", ft = "go" },
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
