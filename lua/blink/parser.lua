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

    if filetype == "vue" then
        require("blink.filetypes.vue").extract_functions(root, functions)
    elseif filetype == "typescript" or filetype == "javascript" then
        require("blink.filetypes.typescript").extract_functions(root, functions)
    else
        require("blink.filetypes.default").extract_functions(root, functions)
    end

    return functions
end

return M
