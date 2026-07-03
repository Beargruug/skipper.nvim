-- filetype parsers
local M = {}
local favorites_by_file = {} -- [filepath] = { list = {...}, set = {} }

--- Generate a stable key for a function target
--- @param target table: { name, line }
--- @return string
local function make_key(target)
    return target.name .. ":" .. tostring(target.line)
end

--- Ensure the favorites structure exists for a filepath
--- @param filepath string
local function ensure_entry(filepath)
    if not favorites_by_file[filepath] then
        favorites_by_file[filepath] = { list = {}, set = {} }
    end
end

local function get_parser(bufnr)
    bufnr = bufnr or 0

    local ok, parsers = pcall(require, "nvim-treesitter.parsers")

    if ok and parsers.get_parser then
        return parsers.get_parser(bufnr)
    else
        return vim.treesitter.get_parser(bufnr)
    end
end

-- Cache per buffer: [bufnr] = { tick = n, functions = {...} }
local functions_cache = {}

function M.get_functions()
    local bufnr = vim.api.nvim_get_current_buf()
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)

    -- Return cached result if buffer hasn't changed
    local cached = functions_cache[bufnr]
    if cached and cached.tick == tick then
        return cached.functions
    end

    local functions = {}
    local parser = get_parser(bufnr)

    if not parser then
        table.insert(functions, { name = "No parser found!" })
        return functions
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    local filetype_map = {
        default = "skipper.filetypes.default",
        vue = "skipper.filetypes.vue",
        typescript = "skipper.filetypes.jtscript",
        javascript = "skipper.filetypes.jtscript",
        typescriptreact = "skipper.filetypes.jtscript",
        javascriptreact = "skipper.filetypes.jtscript",
    }

    local module = filetype_map[vim.bo.filetype] or filetype_map["default"]

    require(module).extract_functions(root, functions)

    if #functions == 0 then
        table.insert(functions, { name = "No functions found!" })
    end

    -- Cache the result
    functions_cache[bufnr] = { tick = tick, functions = functions }

    return functions
end

--- @return string: The current file path
local function get_current_filepath()
    return vim.api.nvim_buf_get_name(0)
end

--- @param target table: The function to save { name, line }
--- @param filepath string|nil: Optional filepath, uses current if nil
function M.save_function(target, filepath)
    if not target then
        return false
    end

    filepath = filepath or get_current_filepath()
    if filepath == "" then
        return false
    end

    ensure_entry(filepath)

    local key = make_key(target)
    if favorites_by_file[filepath].set[key] then
        return false -- Already exists
    end

    favorites_by_file[filepath].set[key] = true
    table.insert(favorites_by_file[filepath].list, target)
    return true
end

--- @param target table: The function to remove { name, line }
--- @param filepath string|nil: Optional filepath, uses current if nil
--- @return boolean: True if removed, false if not found
function M.remove_function(target, filepath)
    if not target then
        return false
    end

    filepath = filepath or get_current_filepath()
    if filepath == "" or not favorites_by_file[filepath] then
        return false
    end

    local key = make_key(target)
    if not favorites_by_file[filepath].set[key] then
        return false
    end

    favorites_by_file[filepath].set[key] = nil
    local list = favorites_by_file[filepath].list
    for i, fav in ipairs(list) do
        if fav.name == target.name and fav.line == target.line then
            table.remove(list, i)
            break
        end
    end

    return true
end

--- @param target table: The function to check { name, line }
--- @param filepath string|nil: Optional filepath, uses current if nil
--- @return boolean: True if in favorites
function M.is_favorite(target, filepath)
    if not target then
        return false
    end

    filepath = filepath or get_current_filepath()
    if filepath == "" or not favorites_by_file[filepath] then
        return false
    end

    return favorites_by_file[filepath].set[make_key(target)] == true
end

--- @param filepath string|nil: Optional filepath, uses current if nil
--- @return table: Array of saved functions
function M.get_saved_functions(filepath)
    filepath = filepath or get_current_filepath()
    if not favorites_by_file[filepath] then
        return {}
    end
    return favorites_by_file[filepath].list
end

--- @param filepath string|nil: Optional filepath, uses current if nil
function M.clear_favorites(filepath)
    filepath = filepath or get_current_filepath()
    favorites_by_file[filepath] = { list = {}, set = {} }
end

return M
