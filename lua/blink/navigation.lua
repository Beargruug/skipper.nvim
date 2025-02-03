-- blink to functions
local M = {}

function M.blink_to_function()
    local buf = vim.api.nvim_get_current_buf()
    local original_buf = vim.api.nvim_buf_get_var(buf, "original_buf") -- Get original buffer ID
    local functions = vim.api.nvim_buf_get_var(buf, "functions")

    local line = vim.fn.line(".")
    local target = functions[line]

    if not target then
        return
    end

    vim.api.nvim_win_close(0, true)
    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_win_set_cursor(0, { target.line + 1, 0 })
    vim.cmd("normal! zz")
end

return M
