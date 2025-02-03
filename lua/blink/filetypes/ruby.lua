local M = {}

function M.extract_functions(root, functions)
    for _, node in ipairs(root:named_children()) do
        if node:type() == "class" then -- Klassenknoten finden
            local body = node:field("body")[1] -- Body-Knoten extrahieren
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
