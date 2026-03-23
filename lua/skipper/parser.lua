-- filetype parsers
local M = {}
local favorites_by_file = {}

local function get_parser(bufnr)
    bufnr = bufnr or 0

    local ok, parsers = pcall(require, "nvim-treesitter.parsers")

    if ok and parsers.get_parser then
        return parsers.get_parser(bufnr)
    else
        return vim.treesitter.get_parser(bufnr)
    end
end

function M.get_functions()
    local functions = {}
    local bufnr = vim.api.nvim_get_current_buf()
    local parser = get_parser(bufnr)

    if not parser then
        table.insert(functions, { name = "No parser found!" })

        return functions
    end

    local tree = parser:parse()[1]
    local root = tree:root()
    local filetype = vim.bo.filetype

    local default = "skipper.filetypes.default"
    local filetype_map = {
        vue = "skipper.filetypes.vue",
        typescript = "skipper.filetypes.typescript",
        javascript = "skipper.filetypes.typescript",
        typescriptreact = "skipper.filetypes.react",
        javascriptreact = "skipper.filetypes.react",
        ruby = "skipper.filetypes.ruby",
    }

    local module = filetype_map[filetype] or default

    require(module).extract_functions(root, functions)

    if #functions == 0 then
        table.insert(functions, { name = "No functions found!" })
    end

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
        return
    end

    filepath = filepath or get_current_filepath()
    if filepath == "" then
        return
    end

    if not favorites_by_file[filepath] then
        favorites_by_file[filepath] = {}
    end

    for _, fav in ipairs(favorites_by_file[filepath]) do
        if fav.name == target.name and fav.line == target.line then
            return false -- Already exists
        end
    end

    table.insert(favorites_by_file[filepath], target)
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

    for i, fav in ipairs(favorites_by_file[filepath]) do
        if fav.name == target.name and fav.line == target.line then
            table.remove(favorites_by_file[filepath], i)
            return true
        end
    end

    return false
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

    for _, fav in ipairs(favorites_by_file[filepath]) do
        if fav.name == target.name and fav.line == target.line then
            return true
        end
    end

    return false
end

--- @param filepath string|nil: Optional filepath, uses current if nil
--- @return table: Array of saved functions
function M.get_saved_functions(filepath)
    filepath = filepath or get_current_filepath()
    return favorites_by_file[filepath] or {}
end

--- @param filepath string|nil: Optional filepath, uses current if nil
function M.clear_favorites(filepath)
    filepath = filepath or get_current_filepath()
    favorites_by_file[filepath] = {}
end

return M
