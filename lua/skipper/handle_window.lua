local M = {}

function M.handle_window()
    local functions = require("skipper.parser").get_functions()
    local UI = require("skipper.ui")
    local mappings = {}

    local errors = {
        ["No functions found!"] = true,
        ["No parser found!"] = true,
    }

    if #functions > 0 and not errors[functions[1].name] then
        mappings["<CR>"] = {
            command = ':lua require("skipper.navigation").skip_to_function()<CR>',
        }
    end

    local content = {}
    for _, line in ipairs(functions) do
        table.insert(content, line.name)
    end

    UI.create({
        mappings = mappings,
        handle_content = function(buf)
            vim.api.nvim_buf_set_var(buf, "functions", functions)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
        end,
    })
end

return M
