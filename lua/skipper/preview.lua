--- Preview module: shows a floating preview of the function under cursor
local M = {}

local preview_win = nil
local preview_buf = nil

--- Close the preview float if open
function M.close()
    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_close(preview_win, true)
    end
    if preview_buf and vim.api.nvim_buf_is_valid(preview_buf) then
        vim.api.nvim_buf_delete(preview_buf, { force = true })
    end
    preview_win = nil
    preview_buf = nil
end

--- Calculate preview window position and dimensions
--- @param position string: "top", "bottom", "left", "right"
--- @param skipper_row number
--- @param skipper_col number
--- @param skipper_width number
--- @param skipper_height number
--- @param pref_width number: Preferred preview width from config
--- @param pref_height number: Preferred preview height from config
--- @return number, number, number, number: row, col, width, height
local function calculate_position(
    position,
    skipper_row,
    skipper_col,
    skipper_width,
    skipper_height,
    pref_width,
    pref_height
)
    local row, col, width, height
    -- border takes 2 chars on each side
    local border_offset = 2
    local gap = 1

    if position == "bottom" then
        width = pref_width
        height = pref_height
        row = skipper_row + skipper_height + border_offset + gap
        col = skipper_col

        -- Clamp width to screen
        if col + width + border_offset > vim.o.columns then
            width = vim.o.columns - col - border_offset
        end

        -- Fallback to top if it overflows
        if row + height + border_offset > vim.o.lines then
            row = skipper_row - height - border_offset - gap
            if row < 0 then
                row = 0
            end
        end
    elseif position == "top" then
        width = pref_width
        height = pref_height
        row = skipper_row - height - border_offset - gap
        col = skipper_col

        -- Clamp width to screen
        if col + width + border_offset > vim.o.columns then
            width = vim.o.columns - col - border_offset
        end

        -- Fallback to bottom if it overflows
        if row < 0 then
            row = skipper_row + skipper_height + border_offset + gap
            if row + height + border_offset > vim.o.lines then
                row = 0
            end
        end
    elseif position == "right" then
        height = pref_height
        row = skipper_row
        col = skipper_col + skipper_width + border_offset + gap

        -- Use preferred width, clamped to available space
        local available = vim.o.columns - col - border_offset
        width = math.min(pref_width, available)
        width = math.max(width, 30)

        -- Fallback to left if it overflows
        if col + width + border_offset > vim.o.columns then
            col = skipper_col - pref_width - border_offset - gap
            width = pref_width
            if col < 0 then
                col = 0
                width = skipper_col - border_offset - gap
                width = math.max(width, 30)
            end
        end
    elseif position == "left" then
        height = pref_height
        row = skipper_row

        -- Use preferred width, clamped to available space
        local available = skipper_col - border_offset - gap
        width = math.min(pref_width, available)
        width = math.max(width, 30)
        col = skipper_col - width - border_offset - gap

        -- Fallback to right if it overflows
        if col < 0 then
            col = skipper_col + skipper_width + border_offset + gap
            local right_available =
                vim.o.columns - col - border_offset
            width = math.min(pref_width, right_available)
            width = math.max(width, 30)
        end
    else
        -- Default to right for invalid values
        return calculate_position(
            "right",
            skipper_row,
            skipper_col,
            skipper_width,
            skipper_height,
            pref_width,
            pref_height
        )
    end

    return row, col, width, height
end

--- Show a preview float for the given target line in the original buffer
--- @param original_buf number: The source buffer to preview
--- @param target_line number: The 0-indexed line to center the preview on
--- @param skipper_win number: The skipper window to position relative to
function M.show(original_buf, target_line, skipper_win)
    local config = require("skipper.config").options

    if not config.preview then
        return
    end

    local preview_height = config.preview_height or 20
    local preview_width = config.preview_width or 80
    local position = config.preview_position or "right"
    local buf_line_count = vim.api.nvim_buf_line_count(original_buf)

    -- Get skipper window geometry
    local skipper_config = vim.api.nvim_win_get_config(skipper_win)
    local skipper_row = skipper_config.row
    local skipper_col = skipper_config.col

    if type(skipper_row) == "table" then
        skipper_row = skipper_row[false] or skipper_row[true] or 0
    end
    if type(skipper_col) == "table" then
        skipper_col = skipper_col[false] or skipper_col[true] or 0
    end

    local skipper_height = skipper_config.height
    local skipper_width = skipper_config.width

    -- Calculate position and dimensions
    local row, col, width, height = calculate_position(
        position,
        skipper_row,
        skipper_col,
        skipper_width,
        skipper_height,
        preview_width,
        preview_height
    )

    -- Calculate the range of lines to show
    local half = math.floor(height / 2)
    local start_line = math.max(0, target_line - half)
    local end_line = math.min(buf_line_count, start_line + height)

    -- Adjust start if we're near the end of the buffer
    if end_line - start_line < height then
        start_line = math.max(0, end_line - height)
    end

    local lines =
        vim.api.nvim_buf_get_lines(original_buf, start_line, end_line, false)

    if #lines == 0 then
        return
    end

    -- Get the filetype of the original buffer for syntax highlighting
    local filetype = vim.api.nvim_get_option_value("filetype", {
        buf = original_buf,
    })

    local title = string.format(" Preview (line %d) ", target_line + 1)

    -- Reuse or create buffer
    if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
        preview_buf = vim.api.nvim_create_buf(false, true)
    end

    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

    -- Apply syntax highlighting if possible
    if filetype and filetype ~= "" then
        vim.api.nvim_set_option_value(
            "filetype",
            filetype,
            { buf = preview_buf }
        )
    end

    local win_opts = {
        relative = "editor",
        width = width,
        height = math.min(height, #lines),
        row = row,
        col = col,
        border = "rounded",
        title = title,
        title_pos = "center",
        style = "minimal",
        focusable = false,
        zindex = 90,
    }

    if preview_win and vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_set_config(preview_win, win_opts)
    else
        preview_win =
            vim.api.nvim_open_win(preview_buf, false, win_opts)
    end

    -- Highlight the target line within the preview
    local highlight_line = target_line - start_line
    vim.api.nvim_buf_clear_namespace(preview_buf, -1, 0, -1)

    local ns = vim.api.nvim_create_namespace("skipper_preview")
    if highlight_line >= 0 and highlight_line < #lines then
        vim.api.nvim_buf_add_highlight(
            preview_buf,
            ns,
            "CursorLine",
            highlight_line,
            0,
            -1
        )
    end
end

return M
