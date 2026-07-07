local M = {}
local FAVORITES_SEPARATOR =
    "────────────────────────────────────────"

--- @param buf integer: The buffer number
--- @param name string: The name of the buffer variable
--- @return any|nil: The value of the buffer variable or nil
local function get_buf_var(buf, name)
    local ok, value = pcall(vim.api.nvim_buf_get_var, buf, name)
    if not ok then
        return nil
    end
    return value
end

--- Skip cursor over separator lines in the given direction
--- @param buf integer: The buffer number
--- @param direction integer: 1 for down, -1 for up
local function skip_separator(buf, direction)
    local current_items = get_buf_var(buf, "all_items")
    if not current_items then
        return
    end

    local cursor_line = vim.fn.line(".")
    local total_lines = vim.api.nvim_buf_line_count(buf)
    local item = current_items[cursor_line]

    if item and item.type == "separator" then
        local next_line = cursor_line + direction
        if next_line >= 1 and next_line <= total_lines then
            vim.api.nvim_win_set_cursor(0, { next_line, 0 })
        else
            -- Can't move further, go back
            local prev_line = cursor_line - direction
            if prev_line >= 1 and prev_line <= total_lines then
                vim.api.nvim_win_set_cursor(0, { prev_line, 0 })
            end
        end
    end
end

local HELP_ITEMS = {
    { key = "<CR>", description = "Jump to function" },
    { key = "j/k", description = "Move cursor (previews target)" },
    { key = "/", description = "Filter functions (fuzzy)" },
    { key = "Up/Down", description = "Select in filter (also C-k/C-j)" },
    { key = "a", description = "Toggle favorite" },
    { key = "x", description = "Remove favorite (in favorites section)" },
    { key = "q", description = "Close window" },
    { key = "<C-c", description = "Close window" },
    { key = "<Esc>", description = "Close window" },
    { key = "?", description = "Toggle this help" },
}

local function build_content(functions, filepath, status)
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
            table.insert(content, "* " .. fav.name)
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

    local status_messages = {
        no_parser = "No parser found!",
        empty = "No functions found!",
    }

    local status_message = status_messages[status]
    if status_message then
        table.insert(content, status_message)
        table.insert(all_items, { type = "status", data = nil })
    end

    return content, all_items, favorites_count, separator_line
end

function M.handle_window()
    local parser = require("skipper.parser")
    local functions, status = parser.get_functions()
    local UI = require("skipper.ui")
    local preview = require("skipper.preview")
    local config = require("skipper.config").options
    local mappings = {}

    local has_valid_functions = status == "ok" and #functions > 0

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
    local original_buf = vim.api.nvim_get_current_buf()

    local content, all_items, favorites_count, separator_line =
        build_content(functions, source_path, status)

    UI.create({
        mappings = mappings,
        help_items = HELP_ITEMS,
        on_close = function()
            preview.close()
        end,
        handle_content = function(buf)
            vim.api.nvim_buf_set_var(buf, "functions", functions)
            vim.api.nvim_buf_set_var(buf, "all_items", all_items)
            vim.api.nvim_buf_set_var(buf, "favorites_count", favorites_count)
            vim.api.nvim_buf_set_var(buf, "separator_line", separator_line or 0)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

            local skipper_win = vim.api.nvim_get_current_win()
            local last_direction = 1
            local skipping = false

            -- Track movement direction via j/k mappings
            vim.keymap.set("n", "j", function()
                last_direction = 1
                vim.cmd("normal! j")
            end, { buffer = buf, noremap = true, silent = true })

            vim.keymap.set("n", "k", function()
                last_direction = -1
                vim.cmd("normal! k")
            end, { buffer = buf, noremap = true, silent = true })

            -- Fuzzy filter keymap
            if has_valid_functions then
                vim.keymap.set("n", "/", function()
                    require("skipper.filter").activate(buf)
                end, {
                    buffer = buf,
                    noremap = true,
                    silent = true,
                })
            end

            -- Skip separator and optionally show preview on cursor move
            vim.api.nvim_create_autocmd("CursorMoved", {
                buffer = buf,
                callback = function()
                    if skipping then
                        return
                    end

                    -- Skip separator line
                    skipping = true
                    skip_separator(buf, last_direction)
                    skipping = false

                    -- Show preview if enabled
                    if config.preview and has_valid_functions then
                        local cursor_line = vim.fn.line(".")
                        local current_items = get_buf_var(buf, "all_items")

                        if not current_items then
                            preview.close()
                            return
                        end

                        local item = current_items[cursor_line]

                        if
                            not item
                            or item.type == "separator"
                            or not item.data
                        then
                            preview.close()
                            return
                        end

                        preview.show(original_buf, item.data.line, skipper_win)
                    end
                end,
            })
        end,
    })
end

M.build_content = build_content

return M
