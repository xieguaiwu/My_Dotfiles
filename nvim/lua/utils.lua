-- ~/.config/nvim/lua/utils.lua

local M = {}

M.CompileRun = function()
    vim.cmd("w") -- 写入文件
    local file = vim.fn.expand('%')
    local base = vim.fn.expand('%<')

    if not vim.fn.filereadable(file) then
        print("Error: File not readable - " .. file)
        return
    end

    local ft = vim.bo.filetype
    local cmd = nil
    local escaped_file = vim.fn.shellescape(file)
    local escaped_base = vim.fn.shellescape(base)

    if ft == 'cpp' or ft == 'cc' then
        cmd = string.format("!g++ -std=c++17 -O2 -Wall %s -o %s", escaped_file, escaped_base)
    elseif ft == 'c' then
        cmd = string.format("!gcc -std=c11 -O2 -Wall %s -o %s", escaped_file, escaped_base)
    elseif ft == 'java' then
        local dir = vim.fn.expand('%:p:h')
        local classname = vim.fn.fnamemodify(file, ':t:r')
        -- 检测 package 声明，支持带包名的 Java 文件
        local pkg_decl = ""
        for _, line in ipairs(vim.fn.readfile(file)) do
            local m = line:match("^%s*package%s+([^;]+)")
            if m then
                pkg_decl = m
                break
            end
        end
        local full_class = classname
        if pkg_decl ~= "" then
            full_class = pkg_decl .. "." .. classname
        end
        cmd = string.format("!javac -d %s %s && java -cp %s %s",
            vim.fn.shellescape(dir), escaped_file,
            vim.fn.shellescape(dir), full_class)
    elseif ft == 'python' then
        cmd = string.format("!python3 %s", escaped_file)
    elseif ft == 'sh' then
        cmd = string.format("!sh %s", escaped_file)
    elseif ft == 'rust' then
        if vim.fn.exists(':RustBuild') == 2 then
            cmd = ":RustBuild | RustRun"
        else
            cmd = string.format("!rustc %s -o %s && %s", escaped_file, escaped_base, escaped_base)
        end
    elseif ft == 'go' then
        cmd = string.format("!go build %s", escaped_file)
    elseif ft == 'haskell' then
        cmd = string.format("!ghc -O2 -Wall -threaded -rtsopts -with-rtsopts=-N -o %s %s", escaped_base, escaped_file)
    elseif ft == 'asm' or ft == 'nasm' then
        local obj_file = vim.fn.shellescape(base .. ".o")
        local exe_file = escaped_base
        local asm_arch = vim.fn.input("Enter architecture (32/64) [64]: ", "64")
        local asm_format = "elf64"

        if asm_arch == "32" then
            asm_format = "elf32"
        end

        -- 先编译为对象文件，然后链接
        cmd = string.format("!nasm -f %s -g %s -o %s && ld -m %s -o %s %s",
            asm_format, escaped_file, obj_file,
            (asm_arch == "32" and "elf_i386" or "elf_x86_64"),
            exe_file, obj_file)
    end

    if cmd then
        vim.cmd(cmd)
    end
end

M.SelfFormat = function()
    local ft = vim.bo.filetype
    local format_command = nil
    local file = vim.fn.expand('%')
    local escaped_file = vim.fn.shellescape(file)

    if ft == 'c' or ft == 'cpp' or ft == 'cc' or ft == 'java' then
        format_command = string.format("!astyle --mode=c --style=java --indent=tab --pad-oper --pad-header --unpad-paren --suffix=none %s", escaped_file)
    elseif ft == 'rust' then
        format_command = string.format("!rustfmt %s", escaped_file)
    elseif ft == 'go' then
        format_command = string.format("!gofmt -w %s", escaped_file)
    elseif ft == 'python' then
        format_command = string.format("!autopep8 --hang-closing --aggressive --in-place %s", escaped_file)
    elseif ft == 'asm' or ft == 'nasm' or ft == 'gas' or ft == 's' then
        -- 使用 expand 规范化空白（安全方式：expand 失败则 mv 不会执行）
        format_command = string.format("!expand -t 8 %s > %s.tmp && mv %s.tmp %s",
            escaped_file, escaped_file, escaped_file, escaped_file)
    elseif ft == 'haskell' then
        -- 不指定 -c，让 stylish-haskell 自动搜索标准配置位置
        format_command = string.format("!stylish-haskell -i %s", escaped_file)
    elseif ft ~= 'tex' then
        if vim.fn.exists(':Autoformat') == 2 then
            format_command = "Autoformat"
        else
            print("SelfFormat: No formatter available for " .. ft)
        end
    end

    if format_command ~= nil then
        vim.cmd("w")
        vim.cmd(format_command)
    end
end

return M
