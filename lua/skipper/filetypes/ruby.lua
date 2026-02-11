local M = {}

local METHOD_TYPES = {
    method = true,
    singleton_method = true,
}

local function extract_methods(node, functions)
    if not node then
        return
    end
    local node_type = node:type()

    if METHOD_TYPES[node_type] then
        local name_node = node:field("name")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(name_node, 0)
            local start_row = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = start_row })
        end
    end

    for child in node:iter_children() do
        extract_methods(child, functions)
    end
end

function M.extract_functions(root, functions)
    extract_methods(root, functions)
end

return M
