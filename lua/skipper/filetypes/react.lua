local M = {}

local function handle_functions(node, functions)
    if node:type() == "export_statement" then
        local export_children = node:named_children()
        for _, export_node in ipairs(export_children) do
            if export_node:type() == "function_declaration" then
                local name_node = export_node:field("name")[1]
                if name_node then
                    local func_name = vim.treesitter.get_node_text(name_node, 0)
                    local line_number =
                        vim.treesitter.get_node_range(export_node)
                    table.insert(
                        functions,
                        { name = func_name, line = line_number }
                    )
                end
            end
            if export_node:type() == "lexical_declaration" then
                for child in export_node:iter_children() do
                    if child:type() == "variable_declarator" then
                        local name_node = child:field("name")[1]
                        if name_node then
                            local func_name =
                                vim.treesitter.get_node_text(name_node, 0)
                            local line_number = ({
                                vim.treesitter.get_node_range(export_node),
                            })[1]

                            table.insert(
                                functions,
                                { name = func_name, line = line_number }
                            )
                        end
                    end
                end
            end
        end
    end
    if node:type() == "function_declaration" then
        local name_node = node:field("name")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(name_node, 0)
            local line_number = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = line_number })
        end
    end
    if node:type() == "function_expression" then
        local name_node = node:field("name")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(name_node, 0)
            local line_number = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = line_number })
        end
    end
    if node:type() == "arrow_function" then
        local name_node = node:field("name")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(name_node, 0)
            local line_number = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = line_number })
        end
    end
    if node:type() == "method_definition" then
        local name_node = node:field("key")[1]
        if name_node then
            local func_name = vim.treesitter.get_node_text(name_node, 0)
            local line_number = vim.treesitter.get_node_range(node)
            table.insert(functions, { name = func_name, line = line_number })
        end
    end
    if node:type() == "lexical_declaration" then
        for child in node:iter_children() do
            if child:type() == "variable_declarator" then
                local name_node = child:field("name")[1]
                local value_node = child:field("value")[1]

                if
                    value_node
                    and value_node:type() == "arrow_function"
                    and name_node
                then
                    local func_name = vim.treesitter.get_node_text(name_node, 0)
                    local line_number = vim.treesitter.get_node_range(child)
                    table.insert(
                        functions,
                        { name = func_name, line = line_number }
                    )
                end
            end
        end
    end
end

function M.extract_functions(root, functions)
    local function traverse(node)
        handle_functions(node, functions)
        for child in node:iter_children() do
            traverse(child)
        end
    end

    traverse(root)
end

return M
