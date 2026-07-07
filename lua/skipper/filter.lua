local M = {}

local PROMPT_PREFIX = "> "
local HIGHLIGHT_NS = "skipper_filter_selection"

-- Per-buffer filter state (keyed by the main skipper buffer)
local filter_state = {}

--- @param buf integer
--- @return table|nil: The filter state for this buffer
local function get_state(buf)
    return filter_state[buf]
end

--- Build filtered content from original items using matchfuzzy
--- @param state table: The filter state
--- @param query string: The current filter query
--- @return table, table: content lines, all_items
local function build_filtered(state, query)
    local content = {}
    local all_items = {}

    if query == "" then
        -- Empty query: show all original items
        for i, item in ipairs(state.original_items) do
            table.insert(content, state.original_content[i])
            table.insert(all_items, item)
        end
    else
        -- Collect names and their original indices for matchfuzzy
        local names = {}
        local index_by_name = {}
        for i, item in ipairs(state.original_items) do
            if item.data and item.data.name then
                table.insert(names, item.data.name)
                if not index_by_name[item.data.name] then
                    index_by_name[item.data.name] = {}
                end
                table.insert(index_by_name[item.data.name], i)
            end
        end

        local matched = vim.fn.matchfuzzy(names, query)

        if #matched == 0 then
            table.insert(content, "No matches")
            table.insert(all_items, { type = "status", data = nil })
        else
            -- Preserve matchfuzzy ranking order
            local used = {}
            for _, name in ipairs(matched) do
                local indices = index_by_name[name]
                if indices then
                    for _, idx in ipairs(indices) do
                        if not used[idx] then
                            used[idx] = true
                            local item = state.original_items[idx]
                            table.insert(content, item.data.name)
                            table.insert(all_items, item)
                            break
                        end
                    end
                end
            end
        end
    end

    return content, all_items
end

--- Create the prompt floating window below the skipper window
--- @param skipper_win integer: The main skipper window
--- @return integer, integer: prompt buffer, prompt window
local function create_prompt_window(skipper_win)
    local skipper_config = vim.api.nvim_win_get_config(skipper_win)

    local row = skipper_config.row
    local col = skipper_config.col

    -- Handle possible table values (older nvim versions)
    if type(row) == "table" then
        row = row[false] or row[true] or 0
    end
    if type(col) == "table" then
        col = col[false] or col[true] or 0
    end

    local width = skipper_config.width
    local height = skipper_config.height

    -- Position prompt directly below the skipper window
    -- Account for border (2 rows: top + bottom)
    local prompt_row = row + height + 2
    local prompt_col = col

    local prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { PROMPT_PREFIX })

    local prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
        relative = "editor",
        width = width,
        height = 1,
        row = prompt_row,
        col = prompt_col,
        border = "rounded",
        title = " Filter ",
        title_pos = "left",
        style = "minimal",
        zindex = 110,
    })

    return prompt_buf, prompt_win
end

--- Highlight the currently selected line in the main skipper window
--- @param main_buf integer: The main skipper buffer
--- @param state table: The filter state
local function highlight_selection(main_buf, state)
    local ns = vim.api.nvim_create_namespace(HIGHLIGHT_NS)
    vim.api.nvim_buf_clear_namespace(main_buf, ns, 0, -1)

    local selected = state.selected_line
    local line_count = vim.api.nvim_buf_line_count(main_buf)

    if selected and selected >= 1 and selected <= line_count then
        vim.api.nvim_buf_add_highlight(
            main_buf,
            ns,
            "CursorLine",
            selected - 1, -- 0-indexed for highlight API
            0,
            -1
        )
    end
end

--- Move the selection cursor in the main window
--- @param main_buf integer: The main skipper buffer
--- @param direction integer: 1 for down, -1 for up
local function move_selection(main_buf, direction)
    local state = get_state(main_buf)
    if not state then
        return
    end

    local ok_items, current_items =
        pcall(vim.api.nvim_buf_get_var, main_buf, "all_items")
    if not ok_items or not current_items or #current_items == 0 then
        return
    end

    local total = #current_items
    local new_line = state.selected_line + direction

    -- Wrap around
    if new_line < 1 then
        new_line = total
    elseif new_line > total then
        new_line = 1
    end

    -- Skip status lines (they have no data)
    local item = current_items[new_line]
    if item and item.type == "status" then
        return -- Don't move to status lines
    end

    state.selected_line = new_line
    highlight_selection(main_buf, state)

    -- Update preview to show the newly selected function
    local config = require("skipper.config").options
    if config.preview and item and item.data and item.data.line then
        local ok_buf, original_buf =
            pcall(vim.api.nvim_buf_get_var, main_buf, "original_buf")
        if ok_buf and original_buf and state.skipper_win then
            local preview = require("skipper.preview")
            preview.show(original_buf, item.data.line, state.skipper_win)
        end
    end
end

--- Apply the current filter query to the main buffer
--- @param main_buf integer: The main skipper buffer
local function apply_filter(main_buf)
    local state = get_state(main_buf)
    if not state then
        return
    end

    -- Read the prompt text from the prompt buffer
    local prompt_buf = state.prompt_buf
    if not prompt_buf then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)
    local prompt_line = lines[1] or ""

    -- Extract query from prompt line
    local query = ""
    if prompt_line:sub(1, #PROMPT_PREFIX) == PROMPT_PREFIX then
        query = prompt_line:sub(#PROMPT_PREFIX + 1)
    else
        -- User deleted the prefix, treat entire line as query
        query = prompt_line
    end

    state.query = query

    local content, new_items = build_filtered(state, query)

    -- Update the main skipper buffer
    vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, content)
    vim.api.nvim_buf_set_var(main_buf, "all_items", new_items)

    -- Reset selection to first item
    state.selected_line = 1
    highlight_selection(main_buf, state)

    -- Update preview to match the new top selection
    local config = require("skipper.config").options
    local preview = require("skipper.preview")
    if config.preview then
        local top_item = new_items[1]
        if top_item and top_item.data and top_item.data.line then
            local ok_buf, original_buf =
                pcall(vim.api.nvim_buf_get_var, main_buf, "original_buf")
            if ok_buf and original_buf and state.skipper_win then
                preview.show(
                    original_buf,
                    top_item.data.line,
                    state.skipper_win
                )
            end
        else
            -- No valid match at top (e.g. "No matches") — close preview
            preview.close()
        end
    end
end

--- Jump to the selected match and close everything
--- @param main_buf integer: The main skipper buffer
local function jump_to_selection(main_buf)
    local state = get_state(main_buf)
    if not state then
        return
    end

    -- Exit insert mode first
    vim.cmd("stopinsert")

    local ok_items, current_items =
        pcall(vim.api.nvim_buf_get_var, main_buf, "all_items")
    if not ok_items or not current_items or #current_items == 0 then
        M.deactivate(main_buf)
        return
    end

    -- Get the selected item
    local selected = state.selected_line or 1
    local target_item = current_items[selected]

    -- If selected item has no data, try to find the first valid item
    if not target_item or not target_item.data or not target_item.data.line then
        target_item = nil
        for _, item in ipairs(current_items) do
            if item.data and item.data.line then
                target_item = item
                break
            end
        end
    end

    if not target_item then
        M.deactivate(main_buf)
        return
    end

    -- Get original buffer reference
    local ok_buf, original_buf =
        pcall(vim.api.nvim_buf_get_var, main_buf, "original_buf")
    if not ok_buf or not original_buf then
        M.deactivate(main_buf)
        return
    end

    -- Close prompt window
    if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
        vim.api.nvim_win_close(state.prompt_win, true)
    end

    -- Clean up filter state
    if state.autocmd_id then
        pcall(vim.api.nvim_del_autocmd, state.autocmd_id)
    end
    filter_state[main_buf] = nil

    -- Close preview and skipper window
    require("skipper.preview").close()
    local skipper_win = state.skipper_win
    if skipper_win and vim.api.nvim_win_is_valid(skipper_win) then
        vim.api.nvim_win_close(skipper_win, true)
    end

    -- Jump to the target in the original buffer
    vim.api.nvim_set_current_buf(original_buf)
    local line_count = vim.api.nvim_buf_line_count(original_buf)
    local target_line = target_item.data.line + 1 -- 0-indexed to 1-indexed

    if target_line > line_count then
        return
    end

    vim.api.nvim_win_set_cursor(0, { target_line, 0 })
    vim.cmd("normal! zz")
end

--- Activate filter mode on the given buffer
--- @param buf integer: The main skipper buffer
function M.activate(buf)
    if get_state(buf) then
        return -- Already active
    end

    -- Save current state
    local current_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local ok_items, current_items =
        pcall(vim.api.nvim_buf_get_var, buf, "all_items")
    if not ok_items then
        return
    end

    local ok_fav, favorites_count =
        pcall(vim.api.nvim_buf_get_var, buf, "favorites_count")
    local ok_sep, separator_line =
        pcall(vim.api.nvim_buf_get_var, buf, "separator_line")

    local skipper_win = vim.api.nvim_get_current_win()

    -- Create the prompt window below the skipper window
    local prompt_buf, prompt_win = create_prompt_window(skipper_win)

    filter_state[buf] = {
        original_content = current_content,
        original_items = current_items,
        original_favorites_count = ok_fav and favorites_count or 0,
        original_separator_line = ok_sep and separator_line or 0,
        query = "",
        selected_line = 1,
        prompt_buf = prompt_buf,
        prompt_win = prompt_win,
        skipper_win = skipper_win,
    }

    -- Highlight the first item
    highlight_selection(buf, filter_state[buf])

    -- Position cursor in prompt buffer after "> " and enter insert mode
    vim.api.nvim_win_set_cursor(prompt_win, { 1, #PROMPT_PREFIX })
    vim.cmd("startinsert!")

    -- Set up TextChangedI autocmd on the PROMPT buffer for live filtering
    local autocmd_id = vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = prompt_buf,
        callback = function()
            apply_filter(buf)
        end,
    })
    filter_state[buf].autocmd_id = autocmd_id

    -- Map <CR> in insert mode on prompt buffer to jump to selection
    vim.keymap.set("i", "<CR>", function()
        jump_to_selection(buf)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    -- Map <Esc> in insert mode on prompt buffer to cancel filter
    vim.keymap.set("i", "<Esc>", function()
        M.deactivate(buf)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    -- Arrow keys to move selection in main window while staying in prompt
    vim.keymap.set("i", "<Down>", function()
        move_selection(buf, 1)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    vim.keymap.set("i", "<Up>", function()
        move_selection(buf, -1)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    -- Also support Ctrl+j/k for vim purists
    vim.keymap.set("i", "<C-j>", function()
        move_selection(buf, 1)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    vim.keymap.set("i", "<C-k>", function()
        move_selection(buf, -1)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    -- Also close filter with Ctrl+c (insert and normal mode)
    vim.keymap.set("i", "<C-c>", function()
        M.deactivate(buf)
    end, { buffer = prompt_buf, noremap = true, silent = true })

    vim.keymap.set("n", "<C-c>", function()
        M.deactivate(buf)
    end, { buffer = prompt_buf, noremap = true, silent = true })
end

--- Deactivate filter mode and restore original content
--- @param buf integer: The main skipper buffer
function M.deactivate(buf)
    local state = get_state(buf)
    if not state then
        return
    end

    -- Exit insert mode
    vim.cmd("stopinsert")

    -- Remove autocmd
    if state.autocmd_id then
        pcall(vim.api.nvim_del_autocmd, state.autocmd_id)
    end

    -- Close prompt window
    if state.prompt_win and vim.api.nvim_win_is_valid(state.prompt_win) then
        vim.api.nvim_win_close(state.prompt_win, true)
    end

    -- Clear selection highlight
    local ns = vim.api.nvim_create_namespace(HIGHLIGHT_NS)
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)

    -- Restore original content in main buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, state.original_content)
    vim.api.nvim_buf_set_var(buf, "all_items", state.original_items)
    vim.api.nvim_buf_set_var(
        buf,
        "favorites_count",
        state.original_favorites_count
    )
    vim.api.nvim_buf_set_var(
        buf,
        "separator_line",
        state.original_separator_line
    )

    -- Return focus to skipper window and move cursor to first line
    if state.skipper_win and vim.api.nvim_win_is_valid(state.skipper_win) then
        vim.api.nvim_set_current_win(state.skipper_win)
    end
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    -- Clear state
    filter_state[buf] = nil
end

--- Check if filter is active on a buffer
--- @param buf integer
--- @return boolean
function M.is_active(buf)
    return get_state(buf) ~= nil
end

-- Expose for testing
M._build_filtered = build_filtered
M._move_selection = move_selection
M._filter_state = filter_state

return M
