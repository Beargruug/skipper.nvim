--- Opts Class
--- @class Opts
--- @field mappings table<string, table<string, string>>
--- @field handle_content function

local M = {}

--- Close a window
--- @param win_id number: The window id to close
local function close(win_id)
    vim.api.nvim_win_close(win_id, true)
end

--- Create a new window
--- @param opts Opts: The options for the window
function M.create(opts)
    local config = require("skipper.config").options

    local win_opts = {
        relative = "editor",
        width = config.win_width,
        height = config.win_height,
        col = math.floor((vim.o.columns - config.win_width) / 2),
        row = math.floor((vim.o.lines - config.win_height) / 2),
        border = config.border,
        title = config.title,
    }

    -- Create buffer and window
    local original_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_var(buf, "original_buf", original_buf)

    local win = vim.api.nvim_open_win(buf, true, win_opts)

    vim.keymap.set("n", "<Esc>", function()
        close(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "<C-c>", function()
        close(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "q", function()
        close(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "<CR>", function()
        close(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })

    for key, mapping in pairs(opts.mappings) do
        vim.api.nvim_buf_set_keymap(
            buf,
            "n",
            key,
            mapping.command,
            mapping.opts or { noremap = true, silent = true }
        )
    end

    if opts.handle_content then
        opts.handle_content(buf)
    end

    -- return {
    --     window = win,
    --     buffer = buf,
    --     close = function()
    --         if opts.on_close then
    --             opts.on_close(buf, win)
    --         end
    --         vim.api.nvim_win_close(win, true)
    --     end,
    -- }
end

return M
