local M = {}
local FAVORITES_SEPARATOR =
    "────────────────────────────────────────"

local HELP_ITEMS = {
    { key = "<CR>", description = "Jump to function" },
    { key = "a", description = "Toggle favorite" },
    { key = "x", description = "Remove favorite (in favorites section)" },
    { key = "j/k", description = "Move cursor down/up" },
    { key = "q", description = "Close window" },
    { key = "<C>-c", description = "Close window" },
    { key = "<Esc>", description = "Close window" },
    { key = "?", description = "Toggle this help" },
}

function M.handle_window()
    local parser = require("skipper.parser")
    local functions = parser.get_functions()
    local UI = require("skipper.ui")
    local mappings = {}

    local errors = {
        ["No functions found!"] = true,
        ["No parser found!"] = true,
    }

    local has_valid_functions = #functions > 0 and not errors[functions[1].name]

    if has_valid_functions then
        mappings["<CR>"] = {
            command = ':lua require("skipper.navigation").skip_to_function()<CR>',
        }
        mappings["a"] = {
            command = ':lua require("skipper.navigation").toggle_favorite()<CR>',
        }
        mappings["x"] = {
            command = ':lua require("skipper.navigation").remove_favorite()<CR>',
        }
    end

    local all_items = {} -- favorites + separator + functions
    local content = {}
    local favorites = parser.get_saved_functions()
    local favorites_count = #favorites
    local separator_line = nil -- Line number of separator (1-indexed in display)

    -- favorites section
    if favorites_count > 0 then
        for _, fav in ipairs(favorites) do
            table.insert(content, "★ " .. fav.name)
            table.insert(all_items, { type = "favorite", data = fav })
        end

        -- Add separator
        table.insert(content, FAVORITES_SEPARATOR)
        separator_line = #content
        table.insert(all_items, { type = "separator", data = nil })
    end

    -- Add all functions
    for _, func in ipairs(functions) do
        local prefix = ""
        if parser.is_favorite(func) then
            prefix = "★ "
        end
        table.insert(content, prefix .. func.name)
        table.insert(all_items, { type = "function", data = func })
    end

    UI.create({
        mappings = mappings,
        help_items = HELP_ITEMS,
        handle_content = function(buf)
            vim.api.nvim_buf_set_var(buf, "functions", functions)
            vim.api.nvim_buf_set_var(buf, "all_items", all_items)
            vim.api.nvim_buf_set_var(buf, "favorites_count", favorites_count)
            vim.api.nvim_buf_set_var(buf, "separator_line", separator_line or 0)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
        end,
    })
end

return M
