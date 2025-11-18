local M = {}

--note: this needs to be refactored soon
function M.extract_functions(root, functions)
    for _, node in ipairs(root:named_children()) do
        if node:type() == "module" then
            local b = node:field("body")[1]
            for _, nod in ipairs(b:named_children()) do
                if
                    nod:type() == "class"
                    or nod:type() == "method"
                    or nod:type() == "singleton_class"
                then
                    if nod:type() == "method" then
                        local name_node = nod:field("name")[1]
                        if name_node then
                            local func_name =
                                vim.treesitter.get_node_text(name_node, 0)
                            local start_row, _, _, _ =
                                vim.treesitter.get_node_range(nod)
                            table.insert(
                                functions,
                                { name = func_name, line = start_row }
                            )
                        end
                    end
                    local body = nod:field("body")[1]
                    if body then
                        for _, method in ipairs(body:named_children()) do
                            if
                                method:type() == "method"
                                or method:type() == "singleton_method"
                            then
                                local name_node = method:field("name")[1]
                                if name_node then
                                    local func_name =
                                        vim.treesitter.get_node_text(
                                            name_node,
                                            0
                                        )
                                    local start_row, _, _, _ =
                                        vim.treesitter.get_node_range(method)
                                    table.insert(
                                        functions,
                                        { name = func_name, line = start_row }
                                    )
                                end
                            end
                        end
                    end
                end
            end
        end
        if node:type() == "class" then
            local body = node:field("body")[1]
            if body then
                for _, method in ipairs(body:named_children()) do
                    if
                        method:type() == "method"
                        or method:type() == "singleton_method"
                    then
                        local name_node = method:field("name")[1]
                        if name_node then
                            local func_name =
                                vim.treesitter.get_node_text(name_node, 0)
                            local start_row, _, _, _ =
                                vim.treesitter.get_node_range(method)
                            table.insert(
                                functions,
                                { name = func_name, line = start_row }
                            )
                        end
                    end
                end
            end
        end
    end
end

return M
