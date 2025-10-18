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
        cmd = string.format("!g++ -g -std=c++17 %s -o %s && ./%s", file, base, base)
    elseif ft == 'c' then
        cmd = string.format("!gcc -g %s -o %s && ./%s", file, base, base)
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
        cmd = string.format("!go run %s", file)
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
    else
        format_command = "Autoformat"
    end

    if format_command ~= nil then
        vim.cmd(":w")
        vim.cmd(format_command)
    end

end

return M
