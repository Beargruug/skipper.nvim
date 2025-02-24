local M = {}

function M.show_functions_window()
    local functions = require("blink.parser").get_functions()
    local UI = require("blink.window")
    local mappings = {}

    if #functions > 0 and functions[1].name ~= "No functions found!" then
        mappings["<CR>"] = {
            command = ':lua require("blink.navigation").blink_to_function()<CR>',
        }
    end

    local win_opts = require("blink.config").options

    UI.create_window({
        width = win_opts.win_width,
        height = win_opts.win_height,
        border = win_opts.border,
        title = "Blink",
        mappings = mappings,
        on_enter = function(buf)
            vim.api.nvim_buf_set_var(buf, "functions", functions)

            for _, line in ipairs(functions) do
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line.name })
            end
        end,
    })
end

return M
