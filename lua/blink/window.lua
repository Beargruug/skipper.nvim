-- window.lua
local M = {}

function M.close_window(win_id)
    vim.api.nvim_win_close(win_id, true)
end

function M.create_window(opts)
    local win_opts = {
        relative = "editor",
        width = opts.width,
        height = opts.height,
        col = math.floor((vim.o.columns - opts.width) / 2),
        row = math.floor((vim.o.lines - opts.height) / 2),
        border = opts.border,
        title = "Blink",
    }

    -- Create buffer and window
    local original_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_var(buf, "original_buf", original_buf)

    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- Set default mappings
    vim.keymap.set("n", "<Esc>", function()
        M.close_window(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "<CR>", function()
        M.close_window(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })

    -- Set additional mappings
    for key, mapping in pairs(opts.mappings) do
        vim.api.nvim_buf_set_keymap(
            buf,
            "n",
            key,
            mapping.command,
            mapping.opts or { noremap = true, silent = true }
        )
    end

    -- Call on_enter callback if provided
    if opts.on_enter then
        opts.on_enter(buf, win)
    end

    -- Return window and buffer IDs
    return {
        window = win,
        buffer = buf,
        close = function()
            if opts.on_close then
                opts.on_close(buf, win)
            end
            vim.api.nvim_win_close(win, true)
        end,
    }
end

return M
