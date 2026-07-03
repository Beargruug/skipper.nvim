local M = {}

--- @param buf integer: The buffer number
--- @param name string: The name of the buffer variable
--- @return integer|nil: The value of the buffer variable or nil if not found
local function get_buf_var(buf, name)
    local ok, value = pcall(vim.api.nvim_buf_get_var, buf, name)

    if not ok then
        vim.notify(
            "Buffer variable '" .. name .. "' not found in buffer " .. buf,
            vim.log.levels.WARN
        )
        return nil
    end

    return value
end

--- @return table|nil: The item at cursor { type, data } or nil
local function get_current_item()
    local current_buf = vim.api.nvim_get_current_buf()
    local all_items = get_buf_var(current_buf, "all_items")

    if not all_items then
        return
    end

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
    local original_buf = get_buf_var(current_buf, "original_buf")

    if not original_buf then
        return
    end

    local item = get_current_item()

    if not item then
        vim.notify("No item found at current line", vim.log.levels.WARN)

        return
    end

    -- skip separator lines
    if item.type == "separator" then
        vim.notify("Cannot navigate to separator line", vim.log.levels.WARN)
        return
    end

    local target = item.data

    if not target then
        vim.notify("No function data found", vim.log.levels.WARN)
        return
    end

    vim.api.nvim_win_close(current_win, true)
    vim.api.nvim_set_current_buf(original_buf)

    local line_count = vim.api.nvim_buf_line_count(original_buf)

    if target.line > line_count then
        vim.notify(
            "Target line " .. target.line .. " is outside buffer bounds",
            vim.log.levels.WARN
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
    if not original_buf then
        return
    end
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
