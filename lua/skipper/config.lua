-- config file for the plugin
local M = {}

M.options = {
    win_width = 0.3,
    win_height = 0.2,
    border = "single",
    title = "Skipper",
    filter_favorites = true,
    preview = true,
    preview_height = 0.2,
    preview_width = 0.3,
    preview_position = "right",
}

--- Check if a value is a valid size (positive integer or fraction in (0, 1))
--- @param v any
--- @return boolean
local function is_valid_size(v)
    if type(v) ~= "number" then
        return false
    end
    if v <= 0 then
        return false
    end
    -- Fractional: 0 < v < 1
    if v < 1 then
        return true
    end
    -- Absolute: must be integer >= 1
    return v == math.floor(v)
end

local VALID_POSITIONS = { top = true, bottom = true, left = true, right = true }

--- Validate user-provided options. Errors on invalid values.
--- Only checks keys that are present in opts.
--- @param opts table
local function validate(opts)
    if not opts or type(opts) ~= "table" then
        return
    end

    local SIZE_MSG = "positive integer or fraction (0 < x < 1)"

    if opts.win_width ~= nil then
        vim.validate({
            win_width = { opts.win_width, is_valid_size, SIZE_MSG },
        })
    end

    if opts.win_height ~= nil then
        vim.validate({
            win_height = { opts.win_height, is_valid_size, SIZE_MSG },
        })
    end

    if opts.preview_width ~= nil then
        vim.validate({
            preview_width = { opts.preview_width, is_valid_size, SIZE_MSG },
        })
    end

    if opts.preview_height ~= nil then
        vim.validate({
            preview_height = {
                opts.preview_height,
                is_valid_size,
                SIZE_MSG,
            },
        })
    end

    if opts.border ~= nil then
        vim.validate({
            border = {
                opts.border,
                function(v)
                    return type(v) == "string" or type(v) == "table"
                end,
                "string or table",
            },
        })
    end

    if opts.title ~= nil then
        vim.validate({ title = { opts.title, "string" } })
    end

    if opts.filter_favorites ~= nil then
        vim.validate({
            filter_favorites = { opts.filter_favorites, "boolean" },
        })
    end

    if opts.preview ~= nil then
        vim.validate({ preview = { opts.preview, "boolean" } })
    end

    if opts.preview_position ~= nil then
        vim.validate({
            preview_position = {
                opts.preview_position,
                function(v)
                    return type(v) == "string" and VALID_POSITIONS[v] == true
                end,
                "one of: top, bottom, left, right",
            },
        })
    end
end

--- Resolve a size value to an absolute number of columns/rows.
--- Fractional values (0 < v < 1) are treated as a percentage of total.
--- Integer values (>= 1) are used as-is.
--- Result is clamped to [10, total - 4].
--- @param value number: The configured size value
--- @param total number: The total available space (vim.o.columns or vim.o.lines)
--- @return integer
function M.resolve_size(value, total)
    local result
    if value < 1 then
        result = math.floor(value * total)
    else
        result = math.floor(value)
    end

    local min_size = 10
    local max_size = total - 4
    if max_size < min_size then
        max_size = min_size
    end

    if result < min_size then
        result = min_size
    elseif result > max_size then
        result = max_size
    end

    return result
end

function M.set(opts)
    validate(opts)
    M.options = vim.tbl_extend("force", M.options, opts or {})
end

return M
