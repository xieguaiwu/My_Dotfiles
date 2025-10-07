-- ~/.config/nvim/lua/lsp/init.lua

local lspconfig = require('lspconfig')
local mason_lspconfig = require('mason-lspconfig')
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- 通用的 on_attach 函数
local on_attach = function(client, bufnr)
    client.server_capabilities.documentFormattingProvider = true
    client.server_capabilities.documentRangeFormattingProvider = true

    local map = vim.keymap.set
    local opts = { noremap = true, silent = true, buffer = bufnr }

    map('n', 'gd', vim.lsp.buf.definition, opts)
    map('n', 'gy', vim.lsp.buf.type_definition, opts)
    map('n', 'gi', vim.lsp.buf.implementation, opts)
    map('n', 'gr', vim.lsp.buf.references, opts)
    map('n', '<leader>rn', vim.lsp.buf.rename, opts)
    map('n', '<leader>ca', vim.lsp.buf.code_action, opts)
    map('n', 'K', vim.lsp.buf.hover, opts)
    map('n', '[d', vim.diagnostic.goto_prev, opts)
    map('n', ']d', vim.diagnostic.goto_next, opts)
    map('n', '<leader>d', vim.diagnostic.open_float, opts)
end

-- 设置 Mason LSP config
mason_lspconfig.setup({
    ensure_installed = {
        --"clangd",
        "rust_analyzer",
        "pyright",
        --"gopls",
        "lua_ls",
    }
})

-- 使用 Mason LSP config 的自动设置功能
mason_lspconfig.setup({
    -- 默认处理程序，用于所有没有特殊配置的服务器
    function(server_name)
        lspconfig[server_name].setup({
            on_attach = on_attach,
            capabilities = capabilities,
        })
    end,

    -- 特殊配置的服务器
    ["rust_analyzer"] = function()
        lspconfig.rust_analyzer.setup({
            on_attach = on_attach,
            capabilities = capabilities,
            settings = {
                ['rust-analyzer'] = {
                    checkOnSave = {
                        command = "clippy",
                    },
                }
            }
        })
    end,

    ["lua_ls"] = function()
        lspconfig.lua_ls.setup({
            on_attach = on_attach,
            capabilities = capabilities,
            settings = {
                Lua = {
                    runtime = {
                        version = 'LuaJIT',
                    },
                    diagnostics = {
                        globals = {'vim'},
                    },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                    },
                    telemetry = { enabled = false },
                },
            },
        })
    end,
})

-- 诊断配置
vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        source = 'always',
        header = '',
        prefix = ' ',
    },
})
