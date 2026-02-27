-- ~/.config/nvim/lua/plugins/init.lua

return {
    -- 1. 颜色主题 (高优先级)
    {
        "erichdongubler/vim-sublime-monokai",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd("colorscheme sublimemonokai")
        end
    },

    -- 2. coc.nvim (LSP + 补全)
    {
        "neoclide/coc.nvim",
        branch = "release",
        lazy = false,
        config = function()
            vim.cmd([[
                " Tab 补全导航
                inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

                " Enter 确认补全
                inoremap <silent><expr> <CR>
                \ pumvisible() ? coc#pum#confirm() :
                \ coc#expandable() ? coc#rpc#request('do:expandSnippet') :
                \ "\<CR>"

                " LSP 快捷键
                nmap <silent> gd <Plug>(coc-definition)
                nmap <silent> gy <Plug>(coc-type-definition)
                nmap <silent> gi <Plug>(coc-implementation)
                nmap <silent> gr <Plug>(coc-references)
                nmap <silent> <leader>rn <Plug>(coc-rename)
                nmap <silent> <leader>ca <Plug>(coc-codeaction)

                " 显示文档
                nnoremap <silent> K :call ShowDocumentation()<CR>
                function! ShowDocumentation()
                    if CocAction('hasProvider', 'hover')
                        call CocActionAsync('doHover')
                    else
                        call feedkeys('K', 'in')
                    endif
                endfunction

                " 诊断导航
                nmap <silent> [d <Plug>(coc-diagnostic-prev)
                nmap <silent> ]d <Plug>(coc-diagnostic-next)
                nmap <silent> <leader>d :CocDiagnostics<CR>

                " 手动触发补全
                inoremap <silent><expr> <A-z> coc#refresh()
            ]])
        end,
    },

    -- 3. Lualine
    {
            "nvim-lualine/lualine.nvim",
            lazy = false,
            opts = {
                options = { theme = "horizon" },
            },
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
                -- quick toggle by <C-p>, fallback to find_files if not in git repo
                { "<C-p>", function()
                    local builtin = require('telescope.builtin')
                    local ok = pcall(builtin.git_files, { show_untracked = true })
                    if not ok then
                        builtin.find_files()
                    end
                end, desc = "Find Files (Telescope)" },
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
            end,
        },
        { "tpope/vim-unimpaired" },
        { "godlygeek/tabular", cmd = "Tabularize" },
        -- Treesitter 语法高亮 (新版 API)
        {
            "nvim-treesitter/nvim-treesitter",
            build = ":TSUpdate",
            init = function()
                -- 安装所有需要的语言解析器
                vim.cmd("silent! TSInstall! c cpp java python sh rust go haskell asm markdown markdown_inline lua vim vimdoc")
            end,
        },
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
        -- Lean Prover
        --{ "leanprover/lean.nvim", ft = "lean" },
        --{ "Julian/lean.nvim", ft = "lean" },
    }
