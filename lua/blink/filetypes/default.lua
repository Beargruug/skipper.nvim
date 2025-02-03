local M = {}

function M.extract_functions(root, functions)
    for _, node in ipairs(root:named_children()) do
        if
            node:type() == "function_declaration"
            or node:type() == "function_expression"
            or node:type() == "arrow_function"
            or node:type() == "method_definition"
            or node:type() == "async_function_declaration"
        then
            local name_node = node:field("name")[1]

            if name_node then
                local func_name = vim.treesitter.get_node_text(name_node, 0)
                local line_number = vim.treesitter.get_node_range(node) -- Should be a table
                table.insert(
                    functions,
                    { name = func_name, line = line_number }
                ) -- Adjust for expected table format
            end
        end
    end
end

return M
