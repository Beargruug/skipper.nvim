local M = {}

-- Node types that contain methods we want to extract
local CONTAINER_TYPES = {
    module = true,
    class = true,
    singleton_class = true, -- class << self
    root = true, -- top-level
}

-- Node types that are methods
local METHOD_TYPES = {
    method = true,
    singleton_method = true, -- def self.foo
}

local function extract_methods(node, functions)
    if not node then
        return
    end
    local node_type = node:type()

    -- If this is a method, extract it
    if METHOD_TYPES[node_type] then
        local name_node = node:field("name")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(node, 0)
            local start_row = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = start_row })
        end
    end

    -- If this is a container, recurse into its body
    if CONTAINER_TYPES[node_type] then
        local body = node:field("body")[1]
        if body then
            for _, child in ipairs(body:named_children()) do
                extract_methods(child, functions)
            end
        end
    end

    if node_type == "root" then
        for _, child in ipairs(node:named_children()) do
            extract_methods(child, functions)
        end
    end
end

function M.extract_functions(root, functions)
    extract_methods(root, functions)
end

return M
