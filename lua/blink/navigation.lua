local M = {}

function M.blink_to_function()
    -- Get current buffer and window
    local current_buf = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    -- Get stored variables
    local original_buf = vim.api.nvim_buf_get_var(current_buf, "original_buf")
    local functions = vim.api.nvim_buf_get_var(current_buf, "functions")

    -- Get current line (1-based in Lua)
    local cursor_line = vim.fn.line(".")

    -- Get target function
    local target = functions[cursor_line]

    if not target then
        vim.api.nvim_err_writeln("No function found at line " .. cursor_line)
        return
    end

    -- Close the floating window
    vim.api.nvim_win_close(current_win, true)

    -- Switch to original buffer
    vim.api.nvim_set_current_buf(original_buf)

    -- Ensure target line exists in original buffer
    local line_count = vim.api.nvim_buf_line_count(original_buf)

    if target.line > line_count then
        vim.api.nvim_err_writeln(
            "Target line " .. target.line .. " is outside buffer bounds"
        )
        return
    end

    -- Set cursor position (target.line should already be 1-based from parser)
    vim.api.nvim_win_set_cursor(0, { target.line + 1, 0 })

    -- Center the screen on the function
    vim.cmd("normal! zz")
end

return M
