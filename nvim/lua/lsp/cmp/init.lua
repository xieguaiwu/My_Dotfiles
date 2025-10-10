-- ~/.config/nvim/lua/cmp/init.lua

local cmp = require('cmp')
local luasnip = require('luasnip')

-- 定义一个通用的图标/外观，让补全更具辨识度
local kind_icons = {
    Text = "",
    Method = "",
    Function = "󰡱",
    Constructor = "",
    Field = "",
    Variable = "",
    Class = "",
    Interface = "",
    Module = "",
    Property = "",
    Unit = "",
    Value = "",
    Enum = "",
    Keyword = "",
    Snippet = "󰉐",
    Color = "",
    File = "",
    Reference = "",
    Folder = "",
    EnumMember = "",
    Constant = "",
    Struct = "",
    Event = "",
    Operator = "",
    TypeParameter = "",
}

cmp.setup({
    -- 补全菜单外观设置
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },

    -- 定义补全源
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },           -- LSP 服务器提供的补全（例如 clangd, pyright）
        { name = 'luasnip' },            -- 代码片段 (Snippets)
        { name = 'buffer',  option = { keyword_length = 3 } }, -- 当前打开的文件内容
        { name = 'path' },               -- 文件路径
    }),

    -- 按键映射 (最重要的一步)
    mapping = cmp.mapping.preset.insert({
        -- Enter 键: 确认选中项，如果是 Snippet，则跳转到下一个占位符
        ['<CR>'] = cmp.mapping.confirm({ select = true }),

        -- Tab 键:
        -- 1. 跳转到下一个 Snippet 占位符 (如果当前是 Snippet)
        -- 2. 补全菜单中向后移动
        ['<Tab>'] = cmp.mapping(function(fallback)
            if luasnip.expand_or_jumpable() then
                luasnip.expand_or_jump()
            elseif cmp.visible() then
                cmp.select_next_item()
            else
                fallback()
            end
        end, { 'i', 's' }),

        -- Shift-Tab 键:
        -- 1. 跳转到上一个 Snippet 占位符
        -- 2. 补全菜单中向前移动
        ['<S-Tab>'] = cmp.mapping(function(fallback)
            if luasnip.jumpable(-1) then
                luasnip.jump(-1)
            elseif cmp.visible() then
                cmp.select_prev_item()
            else
                fallback()
            end
        end, { 'i', 's' }),

        -- Ctrl+Space: 手动触发补全
        ['<C-=>'] = cmp.mapping.complete(),

        -- Ctrl+E: 关闭补全菜单
        ['<C-e>'] = cmp.mapping.abort(),

        -- Ctrl+P/N: 补全菜单中向上/向下移动 (如果不喜欢 Tab/Shift-Tab 也可以用这个)
        -- ['<C-p>'] = cmp.mapping.select_prev_item(),
        -- ['<C-n>'] = cmp.mapping.select_next_item(),

    }),

    -- 外观定制
    formatting = {
        fields = { 'kind', 'abbr', 'menu' },
        format = function(entry, vim_item)
            -- 添加图标
            vim_item.kind = string.format('%s %s', kind_icons[vim_item.kind], vim_item.kind)
            vim_item.menu = ({
                nvim_lsp = "[LSP]",
                luasnip = "[Snip]",
                buffer = "[Buffer]",
                path = "[Path]",
            })[entry.source.name]
            return vim_item
        end,
    },
})

-- 设置命令行模式下的补全 (例如在 : 后面)
cmp.setup.cmdline('/', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
        { name = 'buffer' }
    }
})
cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
        { name = 'path' }
    }, {
        { name = 'cmdline' }
    })
})
