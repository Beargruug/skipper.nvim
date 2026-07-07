-- vue filetype extractor using treesitter language injections
local M = {}
local utils = require("skipper.filetypes.utils")

--- Vue-specific composable wrappers that contain function arguments
local COMPOSABLE_WRAPPERS = {
    computed = true,
    ref = true,
    reactive = true,
    watch = true,
    watchEffect = true,
    watchPostEffect = true,
    watchSyncEffect = true,
}

--- Check if a call_expression name looks like a Vue lifecycle hook
--- @param name string
--- @return boolean
local function is_lifecycle_hook(name)
    return name:match("^on[%u]") ~= nil
end

--- Vue-specific visitor that extends the JS function catcher.
--- Catches composable wrappers (computed, ref, etc.) and lifecycle hooks.
--- @param node userdata
--- @param functions table
local function catch_vue_function(node, functions)
    local node_type = node:type()

    -- Handle: const foo = computed(() => ...) / const foo = ref(...)
    if
        node_type == "lexical_declaration"
        or node_type == "variable_declaration"
    then
        for child in node:iter_children() do
            if child:type() == "variable_declarator" then
                local value = child:field("value")[1]
                if value and value:type() == "call_expression" then
                    local callee = value:field("function")[1]
                    if callee then
                        local callee_name =
                            vim.treesitter.get_node_text(callee, 0)
                        if COMPOSABLE_WRAPPERS[callee_name] then
                            local name_node = child:field("name")[1]
                            if name_node then
                                local func_name =
                                    vim.treesitter.get_node_text(name_node, 0)
                                local start_row =
                                    vim.treesitter.get_node_range(child)
                                table.insert(functions, {
                                    name = func_name,
                                    line = start_row,
                                })
                            end
                        end
                    end
                end
            end
        end
        -- Still run the normal JS handler for regular const fn = () => ...
        utils.catch_js_function(node, functions)
        return
    end

    -- Handle: onMounted(() => { ... }), onBeforeUnmount(() => { ... }), etc.
    if node_type == "expression_statement" then
        for child in node:iter_children() do
            if child:type() == "call_expression" then
                local callee = child:field("function")[1]
                if callee then
                    local callee_name = vim.treesitter.get_node_text(callee, 0)
                    if is_lifecycle_hook(callee_name) then
                        local start_row = vim.treesitter.get_node_range(child)
                        table.insert(functions, {
                            name = callee_name,
                            line = start_row,
                        })
                    end
                end
            end
        end
        return
    end

    -- Fall through to normal JS function catching
    utils.catch_js_function(node, functions)
end

local JS_LANGS = {
    javascript = true,
    typescript = true,
    tsx = true,
}

function M.extract_functions(root, functions)
    -- Use treesitter language injections to walk JS/TS subtrees
    local ok, ltree = pcall(vim.treesitter.get_parser, 0)
    if not ok or not ltree then
        -- Fallback: walk the root directly (shouldn't happen normally)
        utils.sail_through(root, functions, catch_vue_function)
        return
    end

    ltree:for_each_tree(function(tree, lang_tree)
        local lang = lang_tree:lang()
        if JS_LANGS[lang] then
            utils.sail_through(tree:root(), functions, catch_vue_function)
        end
    end)
end

return M
