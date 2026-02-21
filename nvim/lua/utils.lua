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

    if ft == 'cpp' or ft == 'cc' then
        cmd = string.format("!g++ -g -std=c++17 --no-pie %s -o %s", file, base)
    elseif ft == 'c' then
        cmd = string.format("!gcc -g %s -o %s", file, base)
    elseif ft == 'java' then
        cmd = string.format("!javac %s && java %s", file, base)
    elseif ft == 'python' then
        cmd = string.format("!python3 %s", file)
    elseif ft == 'sh' then
        cmd = string.format("!sh %s", file)
    elseif ft == 'rust' then
        cmd = ":RustBuild | RustRun"
    elseif ft == 'tex' then
        cmd = string.format("!pdflatex %s", file)
    elseif ft == 'go' then
        cmd = string.format("!go build %s", file)
    elseif ft == 'haskell' then
        cmd = string.format("!ghc -o %s %s && ./%s", base, file, base)
    elseif ft == 'asm' or ft == 'nasm' then
        local obj_file = base .. ".o"
        local exe_file = base
        local asm_arch = vim.fn.input("Enter architecture (32/64) [64]: ", "64")
        local asm_format = "elf64"

        if asm_arch == "32" then
            asm_format = "elf32"
        end

        -- 先编译为对象文件，然后链接
        cmd = string.format("!nasm -f %s -g %s -o %s && ld -m %s -o %s %s",
            asm_format, file, obj_file,
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

    if ft == 'c' or ft == 'cpp' or ft == 'cc' or ft == 'java' then
        format_command = string.format("!astyle --mode=c --style=java --indent=tab --pad-oper --pad-header --unpad-paren --suffix=none %s", vim.fn.expand('%'))
    elseif ft == 'rust' then
        format_command = string.format("!rustfmt %s", vim.fn.expand('%'))
    elseif ft == 'go' then
        format_command = string.format("!gofmt -w %s", vim.fn.expand('%'))
    elseif ft == 'python' then
        format_command = string.format("!autopep8 --hang-closing --aggressive --in-place %s", vim.fn.expand('%'))
    elseif ft == 'asm' or ft == 'nasm' or ft == 'gas' or ft == 's' then
        -- 汇编代码格式化：使用indent或自定义脚本
        format_command = string.format("!cat %s | expand -t 8 | unexpand -t 8 > %s.tmp && mv %s.tmp %s",
            vim.fn.expand('%'), vim.fn.expand('%'),
            vim.fn.expand('%'), vim.fn.expand('%'))
    else
        format_command = "Autoformat"
    end

    if format_command ~= nil then
        vim.cmd(":w")
        vim.cmd(format_command)
    end

end

return M
