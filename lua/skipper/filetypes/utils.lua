local M = {}

--- Recursively walks a tree-sitter node tree, calling visitor on each node
--- @param node userdata: The root node to start traversal from
--- @param functions table: List to collect extracted functions into
--- @param visitor fun(node: userdata, functions: table) Invoked on each node
--- @param max_depth? integer: Maximum depth to traverse (nil for unlimited)
--- @param current_depth? integer: Current recursion depth (internal, do not pass)
function M.sail_through(node, functions, visitor, max_depth, current_depth)
    current_depth = current_depth or 0
    if max_depth and current_depth > max_depth then
        return
    end

    visitor(node, functions)

    ---@diagnostic disable-next-line: undefined-field
    for child in node:iter_children() do
        M.sail_through(child, functions, visitor, max_depth, current_depth + 1)
    end
end

local NAME_FIELD = {
    function_declaration = "name",
    function_expression = "name",
    arrow_function = "name",
    method_definition = "key",
    async_function_declaration = "name",
}

function M.catch_js_function(node, functions)
    local node_type = node:type()

    if node_type == "export_statement" then
        for _, child in ipairs(node:named_children()) do
            M.catch_js_function(child, functions)
        end
        return
    end

    if node_type == "pair" then
        local key = node:field("key")[1]
        local value = node:field("value")[1]
        if
            value
            and key
            and (
                value:type() == "function_expression"
                or value:type() == "arrow_function"
            )
        then
            local func_name = vim.treesitter.get_node_text(key, 0)
            local start_row = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = start_row })
        end
        return
    end

    if
        node_type == "lexical_declaration"
        or node_type == "variable_declaration"
    then
        for child in node:iter_children() do
            if child:type() == "variable_declarator" then
                local value = child:field("value")[1]
                if
                    value
                    and (
                        value:type() == "arrow_function"
                        or value:type() == "function_expression"
                    )
                then
                    local name_node = child:field("name")[1]
                    if name_node then
                        local func_name =
                            vim.treesitter.get_node_text(name_node, 0)
                        local start_row = vim.treesitter.get_node_range(child)
                        table.insert(
                            functions,
                            { name = func_name, line = start_row }
                        )
                    end
                end
            end
        end
        return
    end

    local field = NAME_FIELD[node_type]
    if not field then
        return
    end

    local name_node = node:field(field)[1]
    if not name_node then
        return
    end

    local func_name = vim.treesitter.get_node_text(name_node, 0)
    local start_row = vim.treesitter.get_node_range(node)
    table.insert(functions, { name = func_name, line = start_row })
end

return M
