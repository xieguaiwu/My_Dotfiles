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
    end

    if cmd then
        vim.cmd(cmd)
    end
end

return M
