local M = {}
local FAVORITES_SEPARATOR =
    "────────────────────────────────────────"

local HELP_ITEMS = {
    { key = "<CR>", description = "Jump to function" },
    { key = "a", description = "Toggle favorite" },
    { key = "x", description = "Remove favorite (in favorites section)" },
    { key = "j/k", description = "Move cursor down/up" },
    { key = "q", description = "Close window" },
    { key = "<C-c", description = "Close window" },
    { key = "<Esc>", description = "Close window" },
    { key = "?", description = "Toggle this help" },
}

local function build_content(functions, filepath)
    local parser = require("skipper.parser")
    local config = require("skipper.config").options
    local favorites = parser.get_saved_functions(filepath)
    local favorites_count = #favorites

    local all_items = {}
    local content = {}
    local separator_line = 0

    -- favorites section
    if favorites_count > 0 then
        for _, fav in ipairs(favorites) do
            table.insert(content, "★ " .. fav.name)
            table.insert(all_items, { type = "favorite", data = fav })
        end

        table.insert(content, FAVORITES_SEPARATOR)
        separator_line = #content
        table.insert(all_items, { type = "separator", data = nil })
    end

    -- Add all functions
    for _, func in ipairs(functions) do
        local is_fav = parser.is_favorite(func, filepath)

        if not (is_fav and config.filter_favorites) then
            local prefix = is_fav and "★ " or ""
            table.insert(content, prefix .. func.name)
            table.insert(all_items, { type = "function", data = func })
        end
    end

    return content, all_items, favorites_count, separator_line
end

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

    local source_path = vim.api.nvim_buf_get_name(0)

    local content, all_items, favorites_count, separator_line =
        build_content(functions, source_path)

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

M.build_content = build_content

return M
