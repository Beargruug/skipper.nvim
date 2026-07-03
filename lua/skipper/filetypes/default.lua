local M = {}

local utils = require("skipper.filetypes.utils")

local function catch_function(node, functions)
    local node_type = node:type()
    if
        (node_type:match("function") or node_type:match("method"))
        and not node_type:match("call")
    then
        local name_node = node:field("name")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(name_node, 0)
            local start_row = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = start_row })
        end
    end
end

function M.extract_functions(root, functions)
    utils.sail_through(root, functions, catch_function)
end

return M
