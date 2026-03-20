-- filetype parsers
local M = {}

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

return M
