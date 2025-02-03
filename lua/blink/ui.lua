-- Ui
local M = {}

function M.show_functions_window()
    local original_buf = vim.api.nvim_get_current_buf() -- Get the current buffer ID
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_var(buf, "original_buf", original_buf) -- Store original buffer ID

    local functions = require("blink.parser").get_functions()
    if #functions == 0 then
        print("No functions found!")
        return
    end

    local win_opts = require("blink.config").options

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = win_opts.win_width,
        height = win_opts.win_height,
        col = math.floor((vim.o.columns - win_opts.win_width) / 2),
        row = math.floor((vim.o.lines - win_opts.win_height) / 2),
        border = win_opts.border,
    })

    local lines = {}
    for _, func in ipairs(functions) do
        table.insert(lines, func.name)
    end

    vim.api.nvim_buf_set_var(buf, "functions", functions) -- Store functions

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    vim.api.nvim_buf_set_keymap(
        buf,
        "n",
        "<cr>",
        ':lua require("blink.navigation").jump_to_function()<cr>',
        { noremap = true, silent = true }
    )
end

return M
