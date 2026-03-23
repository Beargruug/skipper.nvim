--- Opts Class
--- @class Opts
--- @field mappings table<string, table<string, string>>
--- @field handle_content function
--- @field help_items table|nil: Array of { key, description } for help display

local M = {}

local help_win = nil
local help_buf = nil

--- @param win_id number: The window id to close
local function close(win_id)
    vim.api.nvim_win_close(win_id, true)
end

local function close_help()
    if help_win and vim.api.nvim_win_is_valid(help_win) then
        vim.api.nvim_win_close(help_win, true)
    end
    help_win = nil
    help_buf = nil
end

--- @param parent_win number: The parent window to position relative to
--- @param help_items table: Array of { key, description }
local function show_help(parent_win, help_items)
    close_help()

    if not help_items or #help_items == 0 then
        return
    end

    local content = { " Keybindings:", "" }
    local max_key_len = 0
    for _, item in ipairs(help_items) do
        if #item.key > max_key_len then
            max_key_len = #item.key
        end
    end

    for _, item in ipairs(help_items) do
        local padding = string.rep(" ", max_key_len - #item.key)
        table.insert(
            content,
            string.format("  %s%s  %s", item.key, padding, item.description)
        )
    end
    table.insert(content, "")
    table.insert(content, " Press ? to close")

    local width = 0

    for _, line in ipairs(content) do
        if #line > width then
            width = #line
        end
    end

    width = width + 2 -- padding

    local height = #content

    local parent_config = vim.api.nvim_win_get_config(parent_win)
    local parent_row = parent_config.row
    local parent_col = parent_config.col

    if type(parent_row) == "table" then
        parent_row = parent_row[false] or parent_row[true] or 0
    end

    if type(parent_col) == "table" then
        parent_col = parent_col[false] or parent_col[true] or 0
    end

    local parent_width = parent_config.width
    local parent_height = parent_config.height

    local row = parent_row + parent_height - height - 1
    local col = parent_col + parent_width - width - 1

    if row < 0 then
        row = parent_row + parent_height - height
    end
    if col < 0 then
        col = parent_col + 1
    end

    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = " Help ",
        title_pos = "center",
        style = "minimal",
        focusable = false,
        zindex = 100,
    }

    help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, content)
    help_win = vim.api.nvim_open_win(help_buf, false, win_opts)

    vim.api.nvim_set_option_value(
        "winhl",
        "Normal:NormalFloat",
        { win = help_win }
    )
end

--- @param parent_win number: The parent window
--- @param help_items table: Array of { key, description }
local function toggle_help(parent_win, help_items)
    if help_win and vim.api.nvim_win_is_valid(help_win) then
        close_help()
    else
        show_help(parent_win, help_items)
    end
end

--- @return string: The hint text
local function get_hint_text()
    return "? for help"
end

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
        footer = " " .. get_hint_text() .. " ",
        footer_pos = "right",
    }

    local original_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_var(buf, "original_buf", original_buf)

    local win = vim.api.nvim_open_win(buf, true, win_opts)

    local function close_all()
        close_help()
        close(win)
    end

    vim.keymap.set("n", "<Esc>", close_all, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "<C-c>", close_all, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "q", close_all, {
        buffer = buf,
        noremap = true,
        silent = true,
    })
    vim.keymap.set("n", "<CR>", close_all, {
        buffer = buf,
        noremap = true,
        silent = true,
    })

    if opts.help_items then
        vim.keymap.set("n", "?", function()
            toggle_help(win, opts.help_items)
        end, {
            buffer = buf,
            noremap = true,
            silent = true,
        })
    end

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
end

return M
