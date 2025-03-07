-- vue
local M = {}

local function blink_to_function_definition(line_content, function_word)
    if not line_content then
        return
    end

    return line_content:find("function%s+" .. function_word .. "%s*%b()")
        or line_content:find(
            "export%s+function%s+" .. function_word .. "%s*%b()"
        )
        or line_content:find("const%s+" .. function_word .. "%s*=%s*%b()")
        or line_content:find(
            "export%s+const%s+" .. function_word .. "%s*=%s*%b()"
        )
        or line_content:find("async%s+" .. function_word .. "%s*%b()")
        or line_content:find("export%s+async%s+" .. function_word .. "%s*%b()")
        or line_content:find(
            "const%s+" .. function_word .. "%s*=%s*async%s*%b()"
        )
        or line_content:find(
            "export%s+const%s+" .. function_word .. "%s*=%s*async%s*%b()"
        )
        or line_content:find(
            "const%s+" .. function_word .. "%s*=%s*computed%s*%s*%b()"
        )
        or line_content:find(
            "export%s+const%s+" .. function_word .. "%s*=%s*computed%s*%s*%b()"
        )
        or line_content:find(
            "const%s+" .. function_word .. "%s*=%s*computed%s*%s*%b%((.-)%s*%)"
        )
        or line_content:find(
            "export%s+const%s+"
                .. function_word
                .. "%s*=%s*computed%s*%s*%b%((.-)%s*%)"
        )
end

local function get_line_by_name(function_name)
    local buf = vim.api.nvim_get_current_buf()
    local function_word = function_name:match("^(%S+)")
    local total_lines = vim.api.nvim_buf_line_count(0)

    for line_num = 1, total_lines do
        local line_content =
            vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)[1]

        if blink_to_function_definition(line_content, function_word) then
            return line_num
        end
    end
end

local function handle_functions(root, functions)
    for _, node in ipairs(root:named_children()) do
        if node:type() == "script_element" then
            local raw_text = vim.treesitter.get_node_text(node, 0)

            for line in raw_text:gmatch("[^\r\n]+") do
                -- Match standards function declarations
                for func_name in
                    line:gmatch("export%s+function%s+([%w_]+)%s*%b()")
                do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end
                for func_name in line:gmatch("function%s+([%w_]+)%s*%b()") do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end

                -- Match arrow functions
                for func_name in
                    line:gmatch("export%s+const%s+([%w_]+)%s*=%s*%b()")
                do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end
                for func_name in line:gmatch("const%s+([%w_]+)%s*=%s*%b()") do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end

                -- Match async arrow functions
                for func_name in
                    line:gmatch("export%s+const%s+([%w_]+)%s*=%s*async%s*%b()")
                do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end
                for func_name in
                    line:gmatch("const%s+([%w_]+)%s*=%s*async%s*%b()")
                do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end

                -- TODO: Match computed functions
                -- Match computed functions
                for func_name in
                    line:gmatch("const%s+([%w_]+)%s*=%s*computed%s*%b()")
                do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end
                -- Match multiline computed functions
                for func_name in
                    line:gmatch(
                        "const%s+([%w_]+)%s*=%s*computed%s*%s*%b%((.-)%s*%)"
                    )
                do
                    table.insert(functions, {
                        name = func_name,
                        line = get_line_by_name(func_name),
                    })
                end

                -- Match any lifecycle hooks
                for func_name in line:gmatch("([%w_]+)%s*%b()") do
                    if func_name:match("^on[%u][%w_]*$") then
                        table.insert(functions, {
                            name = func_name,
                            line = get_line_by_name(func_name),
                        })
                    end
                end
            end
        end
    end
end

function M.extract_functions(root, functions)
    handle_functions(root, functions)
end

return M
