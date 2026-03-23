local M = {}

--- @return table|nil: The item at cursor { type, data } or nil
local function get_current_item()
    local current_buf = vim.api.nvim_get_current_buf()
    local all_items = vim.api.nvim_buf_get_var(current_buf, "all_items")
    local cursor_line = vim.fn.line(".")

    return all_items[cursor_line]
end

local function refresh_window()
    local current_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_close(current_win, true)
    require("skipper.handle_window").handle_window()
end

function M.skip_to_function()
    -- Get current buffer and window
    local current_buf = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_buf_get_var(current_buf, "original_buf")

    local item = get_current_item()

    if not item then
        vim.api.nvim_err_writeln("No item found at current line")
        return
    end

    -- skip separator lines
    if item.type == "separator" then
        vim.api.nvim_err_writeln("Cannot navigate to separator line")
        return
    end

    local target = item.data

    if not target then
        vim.api.nvim_err_writeln("No function data found")
        return
    end

    vim.api.nvim_win_close(current_win, true)
    vim.api.nvim_set_current_buf(original_buf)

    local line_count = vim.api.nvim_buf_line_count(original_buf)

    if target.line > line_count then
        vim.api.nvim_err_writeln(
            "Target line " .. target.line .. " is outside buffer bounds"
        )
        return
    end

    vim.api.nvim_win_set_cursor(0, { target.line + 1, 0 })

    vim.cmd("normal! zz")
end

function M.toggle_favorite()
    local current_buf = vim.api.nvim_get_current_buf()
    local original_buf = vim.api.nvim_buf_get_var(current_buf, "original_buf")
    local filepath = vim.api.nvim_buf_get_name(original_buf)

    local item = get_current_item()

    if not item or item.type == "separator" then
        return
    end

    local target = item.data
    local parser = require("skipper.parser")

    if parser.is_favorite(target, filepath) then
        parser.remove_function(target, filepath)
        vim.notify(
            "Removed from favorites: " .. target.name,
            vim.log.levels.INFO
        )
    else
        parser.save_function(target, filepath)
        vim.notify("Added to favorites: " .. target.name, vim.log.levels.INFO)
    end

    refresh_window()
end

function M.remove_favorite()
    local current_buf = vim.api.nvim_get_current_buf()
    local original_buf = vim.api.nvim_buf_get_var(current_buf, "original_buf")
    local filepath = vim.api.nvim_buf_get_name(original_buf)

    local item = get_current_item()

    if not item or item.type ~= "favorite" then
        vim.notify("Cursor is not on a favorite", vim.log.levels.WARN)
        return
    end

    local target = item.data
    local parser = require("skipper.parser")

    if parser.remove_function(target, filepath) then
        vim.notify(
            "Removed from favorites: " .. target.name,
            vim.log.levels.INFO
        )
        refresh_window()
    end
end

function M.add_to_favorite()
    M.toggle_favorite()
end

return M
