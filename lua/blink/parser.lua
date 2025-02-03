-- filetype parsers
local M = {}
local parsers = require("nvim-treesitter.parsers")

function M.get_functions()
    local functions = {}
    local parser = parsers.get_parser()
    if not parser then
        return functions
    end

    local tree = parser:parse()[1]
    local root = tree:root()
    local filetype = vim.bo.filetype

    local default = "blink.filetypes.default"
    local filetype_map = {
        vue = "blink.filetypes.vue",
        typescript = "blink.filetypes.typescript",
        javascript = "blink.filetypes.typescript",
        ruby = "blink.filetypes.ruby",
    }

    local module = filetype_map[filetype] or default

    require(module).extract_functions(root, functions)

    return functions
end

return M
