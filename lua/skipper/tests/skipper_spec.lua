---@diagnostic disable: unused-local
local mock_buf_vars = {}
local mock_buf_lines = {}
local mock_buf_name = "/tmp/test_file.lua"
local mock_current_buf = 1
local mock_changedtick = 1

if not _G.vim then
    ---@diagnostic disable-next-line: lowercase-global
    _G.vim = {
        api = {
            nvim_get_current_buf = function()
                return mock_current_buf
            end,
            nvim_buf_get_changedtick = function()
                return mock_changedtick
            end,
            nvim_buf_get_name = function()
                return mock_buf_name
            end,
            nvim_buf_get_var = function(buf, name)
                if mock_buf_vars[buf] and mock_buf_vars[buf][name] ~= nil then
                    return mock_buf_vars[buf][name]
                end
                error("Key not found: " .. name)
            end,
            nvim_buf_set_var = function(buf, name, value)
                if not mock_buf_vars[buf] then
                    mock_buf_vars[buf] = {}
                end
                mock_buf_vars[buf][name] = value
            end,
            nvim_buf_set_lines = function(buf, _, _, _, lines)
                mock_buf_lines[buf] = lines
            end,
            nvim_create_buf = function()
                return 42
            end,
            nvim_open_win = function()
                return 1
            end,
            nvim_win_close = function() end,
            nvim_get_current_win = function()
                return 1
            end,
            nvim_win_set_cursor = function() end,
            nvim_buf_line_count = function()
                return 10
            end,
            nvim_set_current_buf = function() end,
            nvim_set_option_value = function() end,
            nvim_win_get_config = function()
                return {
                    row = 5,
                    col = 5,
                    width = 60,
                    height = 20,
                }
            end,
            nvim_win_is_valid = function()
                return false
            end,
            nvim_create_autocmd = function() end,
            nvim_buf_set_keymap = function() end,
        },
        fn = {
            line = function()
                return 1
            end,
        },
        bo = { filetype = "lua" },
        wo = {},
        o = { columns = 120, lines = 40 },
        keymap = {
            set = function() end,
        },
        cmd = function() end,
        notify = function() end,
        tbl_extend = function(behavior, ...)
            local result = {}
            for _, tbl in ipairs({ ... }) do
                for k, v in pairs(tbl) do
                    result[k] = v
                end
            end
            return result
        end,
        log = { levels = { WARN = 2, INFO = 1, ERROR = 3 } },
        validate = function(spec)
            for name, rule in pairs(spec) do
                local value = rule[1]
                local validator = rule[2]
                local msg = rule[3]

                local ok
                if type(validator) == "string" then
                    ok = type(value) == validator
                    msg = msg or validator
                elseif type(validator) == "function" then
                    ok = validator(value)
                else
                    ok = false
                end

                if not ok then
                    error(
                        string.format(
                            "%s: expected %s, got %s",
                            name,
                            msg or "valid value",
                            tostring(value)
                        )
                    )
                end
            end
        end,
        treesitter = {
            get_node_text = function()
                return "mock_func"
            end,
            get_node_range = function()
                return 0
            end,
            get_parser = function()
                return nil
            end,
        },
    }
    vim = _G.vim
end

-- Mock nvim-treesitter.parsers
package.loaded["nvim-treesitter.parsers"] = {
    get_parser = function()
        return nil
    end,
}

-- Clear module cache so fresh requires work
package.loaded["skipper.parser"] = nil
package.loaded["skipper.config"] = nil
package.loaded["skipper.handle_window"] = nil

-- ─────────────────────────────────────────────────────────────────────────────
-- Config tests
-- ─────────────────────────────────────────────────────────────────────────────
describe("Config", function()
    local config

    before_each(function()
        package.loaded["skipper.config"] = nil
        config = require("skipper.config")
    end)

    it("should have sensible defaults", function()
        assert.is_not_nil(config.options)
        assert.are.equal(0.3, config.options.win_width)
        assert.are.equal(0.2, config.options.win_height)
        assert.are.equal("single", config.options.border)
        assert.are.equal("Skipper", config.options.title)
        assert.is_true(config.options.filter_favorites)
        assert.is_true(config.options.preview)
    end)

    it("should merge user options via set()", function()
        config.set({ win_width = 80, title = "MyNav" })

        assert.are.equal(80, config.options.win_width)
        assert.are.equal("MyNav", config.options.title)
        -- Other defaults remain
        assert.are.equal(0.2, config.options.win_height)
        assert.are.equal("single", config.options.border)
    end)

    it("should handle set() with nil gracefully", function()
        config.set(nil)
        assert.are.equal(0.3, config.options.win_width)
    end)

    it("should handle set() with empty table", function()
        config.set({})
        assert.are.equal(0.3, config.options.win_width)
        assert.are.equal("Skipper", config.options.title)
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Parser - get_functions() structured status
-- ─────────────────────────────────────────────────────────────────────────────
describe("Parser - get_functions", function()
    local parser

    before_each(function()
        package.loaded["skipper.parser"] = nil
        -- Reset treesitter mock
        package.loaded["nvim-treesitter.parsers"] = {
            get_parser = function()
                return nil
            end,
        }
        mock_changedtick = mock_changedtick + 1
        parser = require("skipper.parser")
    end)

    it(
        "should return empty table and 'no_parser' when no parser found",
        function()
            package.loaded["nvim-treesitter.parsers"] = {
                get_parser = function()
                    return nil
                end,
            }
            package.loaded["skipper.parser"] = nil
            parser = require("skipper.parser")

            local functions, status = parser.get_functions()

            assert.are.same({}, functions)
            assert.are.equal("no_parser", status)
        end
    )

    it(
        "should return 'empty' status when parser returns no functions",
        function()
            local mock_root = {
                named_children = function()
                    return {}
                end,
            }
            local mock_tree = {
                root = function()
                    return mock_root
                end,
            }
            package.loaded["nvim-treesitter.parsers"] = {
                get_parser = function()
                    return {
                        parse = function()
                            return { mock_tree }
                        end,
                    }
                end,
            }
            -- Mock default extractor to return nothing
            package.loaded["skipper.filetypes.default"] = {
                extract_functions = function() end,
            }
            package.loaded["skipper.parser"] = nil
            mock_changedtick = mock_changedtick + 1
            parser = require("skipper.parser")

            local functions, status = parser.get_functions()

            assert.are.same({}, functions)
            assert.are.equal("empty", status)
        end
    )

    it(
        "should return functions and 'ok' status when functions found",
        function()
            local mock_name_node = {
                type = function()
                    return "identifier"
                end,
            }
            local mock_func_node = {
                type = function()
                    return "function_declaration"
                end,
                field = function(_, name)
                    if name == "name" then
                        return { mock_name_node }
                    end
                    return {}
                end,
                named_children = function()
                    return {}
                end,
            }
            local mock_root = {
                named_children = function()
                    return { mock_func_node }
                end,
            }
            local mock_tree = {
                root = function()
                    return mock_root
                end,
            }
            package.loaded["nvim-treesitter.parsers"] = {
                get_parser = function()
                    return {
                        parse = function()
                            return { mock_tree }
                        end,
                    }
                end,
            }
            -- Mock the default filetype extractor
            package.loaded["skipper.filetypes.default"] = {
                extract_functions = function(_, functions)
                    table.insert(functions, { name = "test_func", line = 5 })
                end,
            }
            package.loaded["skipper.parser"] = nil
            mock_changedtick = mock_changedtick + 1
            parser = require("skipper.parser")

            local functions, status = parser.get_functions()

            assert.are.equal("ok", status)
            assert.are.equal(1, #functions)
            assert.are.equal("test_func", functions[1].name)
            assert.are.equal(5, functions[1].line)
        end
    )

    it("should cache results and return same on repeated calls", function()
        package.loaded["skipper.filetypes.default"] = {
            extract_functions = function(_, functions)
                table.insert(functions, { name = "cached_fn", line = 1 })
            end,
        }
        local mock_root = {
            named_children = function()
                return {}
            end,
        }
        local mock_tree = {
            root = function()
                return mock_root
            end,
        }
        local call_count = 0
        package.loaded["nvim-treesitter.parsers"] = {
            get_parser = function()
                return {
                    parse = function()
                        call_count = call_count + 1
                        return { mock_tree }
                    end,
                }
            end,
        }
        package.loaded["skipper.parser"] = nil
        mock_changedtick = mock_changedtick + 1
        parser = require("skipper.parser")

        local f1, s1 = parser.get_functions()
        local f2, s2 = parser.get_functions()

        -- Same references from cache
        assert.are.equal(f1, f2)
        assert.are.equal(s1, s2)
        -- Parser only called once
        assert.are.equal(1, call_count)
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Parser - Favorites API
-- ─────────────────────────────────────────────────────────────────────────────
describe("Parser - Favorites", function()
    local parser
    local filepath = "/tmp/test_file.lua"

    before_each(function()
        package.loaded["skipper.parser"] = nil
        mock_buf_name = filepath
        parser = require("skipper.parser")
        parser.clear_favorites(filepath)
    end)

    it("should save a function to favorites", function()
        local target = { name = "my_func", line = 10 }
        local result = parser.save_function(target, filepath)

        assert.is_true(result)
        assert.is_true(parser.is_favorite(target, filepath))
    end)

    it("should not duplicate a favorite", function()
        local target = { name = "my_func", line = 10 }
        parser.save_function(target, filepath)
        local result = parser.save_function(target, filepath)

        assert.is_false(result)
        -- Only one entry in the list
        local saved = parser.get_saved_functions(filepath)
        assert.are.equal(1, #saved)
    end)

    it("should remove a function from favorites", function()
        local target = { name = "remove_me", line = 20 }
        parser.save_function(target, filepath)

        local result = parser.remove_function(target, filepath)

        assert.is_true(result)
        assert.is_false(parser.is_favorite(target, filepath))
    end)

    it("should return false when removing non-existent favorite", function()
        local target = { name = "ghost", line = 99 }
        local result = parser.remove_function(target, filepath)

        assert.is_false(result)
    end)

    it("should handle nil target gracefully", function()
        assert.is_false(parser.save_function(nil, filepath))
        assert.is_false(parser.remove_function(nil, filepath))
        assert.is_false(parser.is_favorite(nil, filepath))
    end)

    it("should return empty list for unknown filepath", function()
        local saved = parser.get_saved_functions("/nonexistent/path.lua")
        assert.are.same({}, saved)
    end)

    it("should clear all favorites for a filepath", function()
        parser.save_function({ name = "fn1", line = 1 }, filepath)
        parser.save_function({ name = "fn2", line = 5 }, filepath)

        parser.clear_favorites(filepath)

        local saved = parser.get_saved_functions(filepath)
        assert.are.same({}, saved)
    end)

    it("should track favorites independently per file", function()
        local other_path = "/tmp/other_file.lua"
        local target = { name = "shared_name", line = 3 }

        parser.save_function(target, filepath)

        assert.is_true(parser.is_favorite(target, filepath))
        assert.is_false(parser.is_favorite(target, other_path))
    end)

    it(
        "should distinguish functions with same name on different lines",
        function()
            local fn_a = { name = "handler", line = 10 }
            local fn_b = { name = "handler", line = 50 }

            parser.save_function(fn_a, filepath)

            assert.is_true(parser.is_favorite(fn_a, filepath))
            assert.is_false(parser.is_favorite(fn_b, filepath))
        end
    )
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- build_content - structured status rendering
-- ─────────────────────────────────────────────────────────────────────────────
describe("build_content", function()
    local build_content
    local parser
    local filepath = "/tmp/test_build.lua"

    before_each(function()
        package.loaded["skipper.parser"] = nil
        package.loaded["skipper.config"] = nil
        package.loaded["skipper.handle_window"] = nil
        mock_buf_name = filepath
        parser = require("skipper.parser")
        parser.clear_favorites(filepath)
        require("skipper.config").set({ filter_favorites = true })
        build_content = require("skipper.handle_window").build_content
    end)

    it("should render 'No parser found!' for no_parser status", function()
        local content, all_items = build_content({}, filepath, "no_parser")

        assert.are.equal(1, #content)
        assert.are.equal("No parser found!", content[1])
        assert.are.equal("status", all_items[1].type)
        assert.is_nil(all_items[1].data)
    end)

    it("should render 'No functions found!' for empty status", function()
        local content, all_items = build_content({}, filepath, "empty")

        assert.are.equal(1, #content)
        assert.are.equal("No functions found!", content[1])
        assert.are.equal("status", all_items[1].type)
    end)

    it("should render function names for ok status", function()
        local functions = {
            { name = "alpha", line = 1 },
            { name = "beta", line = 10 },
            { name = "gamma", line = 20 },
        }

        local content, all_items = build_content(functions, filepath, "ok")

        assert.are.equal(3, #content)
        assert.are.equal("alpha", content[1])
        assert.are.equal("beta", content[2])
        assert.are.equal("gamma", content[3])

        for _, item in ipairs(all_items) do
            assert.are.equal("function", item.type)
            assert.is_not_nil(item.data)
        end
    end)

    it("should render favorites section with separator", function()
        parser.save_function({ name = "fav_fn", line = 5 }, filepath)

        local functions = {
            { name = "fav_fn", line = 5 },
            { name = "other_fn", line = 15 },
        }

        local content, all_items, favorites_count, separator_line =
            build_content(functions, filepath, "ok")

        assert.are.equal(1, favorites_count)
        -- favorites + separator + remaining functions
        -- With filter_favorites=true, fav_fn shouldn't appear in functions section
        assert.are.equal("* fav_fn", content[1])
        assert.are.equal("favorite", all_items[1].type)
        assert.are.equal(2, separator_line)
        assert.are.equal("separator", all_items[2].type)
        assert.are.equal("other_fn", content[3])
        assert.are.equal("function", all_items[3].type)
    end)

    it(
        "should show star prefix for favorites when filter_favorites is false",
        function()
            package.loaded["skipper.config"] = nil
            local config = require("skipper.config")
            config.set({ filter_favorites = false })

            -- Reload handle_window to pick up new config
            package.loaded["skipper.handle_window"] = nil
            build_content = require("skipper.handle_window").build_content

            parser.save_function({ name = "starred_fn", line = 7 }, filepath)

            local functions = {
                { name = "starred_fn", line = 7 },
                { name = "normal_fn", line = 12 },
            }

            local content, all_items = build_content(functions, filepath, "ok")

            -- Favorites section
            assert.are.equal("* starred_fn", content[1])
            -- After separator, starred_fn appears with star prefix
            local found_starred = false
            for i, line in ipairs(content) do
                if line == "★ starred_fn" then
                    found_starred = true
                    assert.are.equal("function", all_items[i].type)
                end
            end
            assert.is_true(found_starred)
        end
    )

    it("should not render status message for ok status", function()
        local functions = { { name = "fn", line = 1 } }
        local content, all_items = build_content(functions, filepath, "ok")

        for _, item in ipairs(all_items) do
            assert.are_not.equal("status", item.type)
        end
    end)

    it("should return zero separator_line when no favorites", function()
        local functions = { { name = "fn", line = 1 } }
        local _, _, favorites_count, separator_line =
            build_content(functions, filepath, "ok")

        assert.are.equal(0, favorites_count)
        assert.are.equal(0, separator_line)
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Config - validation
-- ─────────────────────────────────────────────────────────────────────────────
describe("Config - validation", function()
    local config

    before_each(function()
        package.loaded["skipper.config"] = nil
        config = require("skipper.config")
    end)

    it("should reject win_width as string", function()
        assert.has_error(function()
            config.set({ win_width = "big" })
        end)
    end)

    it("should reject negative win_width", function()
        assert.has_error(function()
            config.set({ win_width = -5 })
        end)
    end)

    it("should reject win_width = 0", function()
        assert.has_error(function()
            config.set({ win_width = 0 })
        end)
    end)

    it("should reject win_width fraction > 1", function()
        assert.has_error(function()
            config.set({ win_width = 1.5 })
        end)
    end)

    it("should reject non-integer win_width >= 1", function()
        assert.has_error(function()
            config.set({ win_width = 60.5 })
        end)
    end)

    it("should reject win_height as boolean", function()
        assert.has_error(function()
            config.set({ win_height = true })
        end)
    end)

    it("should reject border as number", function()
        assert.has_error(function()
            config.set({ border = 123 })
        end)
    end)

    it("should reject invalid preview_position", function()
        assert.has_error(function()
            config.set({ preview_position = "diagonal" })
        end)
    end)

    it("should reject title as number", function()
        assert.has_error(function()
            config.set({ title = 42 })
        end)
    end)

    it("should reject filter_favorites as string", function()
        assert.has_error(function()
            config.set({ filter_favorites = "yes" })
        end)
    end)

    it("should reject preview as string", function()
        assert.has_error(function()
            config.set({ preview = "true" })
        end)
    end)

    it("should accept valid fractional win_width", function()
        assert.has_no.errors(function()
            config.set({ win_width = 0.6 })
        end)
        assert.are.equal(0.6, config.options.win_width)
    end)

    it("should accept valid integer win_width", function()
        assert.has_no.errors(function()
            config.set({ win_width = 80 })
        end)
        assert.are.equal(80, config.options.win_width)
    end)

    it("should accept fractional preview_height", function()
        assert.has_no.errors(function()
            config.set({ preview_height = 0.3 })
        end)
        assert.are.equal(0.3, config.options.preview_height)
    end)

    it("should accept border as string", function()
        assert.has_no.errors(function()
            config.set({ border = "rounded" })
        end)
        assert.are.equal("rounded", config.options.border)
    end)

    it("should accept border as table", function()
        local custom_border =
            { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
        assert.has_no.errors(function()
            config.set({ border = custom_border })
        end)
        assert.are.same(custom_border, config.options.border)
    end)

    it("should accept valid preview_position values", function()
        for _, pos in ipairs({ "top", "bottom", "left", "right" }) do
            package.loaded["skipper.config"] = nil
            config = require("skipper.config")
            assert.has_no.errors(function()
                config.set({ preview_position = pos })
            end)
        end
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Config - resolve_size
-- ─────────────────────────────────────────────────────────────────────────────
describe("Config - resolve_size", function()
    local resolve_size

    before_each(function()
        package.loaded["skipper.config"] = nil
        resolve_size = require("skipper.config").resolve_size
    end)

    it("should convert 0.6 with total=100 to 60", function()
        assert.are.equal(60, resolve_size(0.6, 100))
    end)

    it("should convert 0.5 with total=200 to 100", function()
        assert.are.equal(100, resolve_size(0.5, 200))
    end)

    it("should convert 0.8 with total=150 to 120", function()
        assert.are.equal(120, resolve_size(0.8, 150))
    end)

    it("should pass through integer values as-is", function()
        assert.are.equal(80, resolve_size(80, 120))
    end)

    it("should clamp small results to minimum of 10", function()
        assert.are.equal(10, resolve_size(5, 100))
    end)

    it("should clamp fractional result to minimum of 10", function()
        assert.are.equal(10, resolve_size(0.05, 100))
    end)

    it("should clamp large values to total - 4", function()
        assert.are.equal(96, resolve_size(200, 100))
    end)

    it("should clamp large fraction to total - 4", function()
        assert.are.equal(96, resolve_size(0.99, 100))
    end)

    it("should handle integer value of 1 as absolute (clamps to 10)", function()
        assert.are.equal(10, resolve_size(1, 100))
    end)

    it("should handle very small total gracefully", function()
        -- When total is 12, max_size = 12 - 4 = 8, but min is 10
        -- So min wins (min_size > max_size case)
        assert.are.equal(10, resolve_size(0.5, 12))
    end)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Vue extractor - treesitter-based
-- ─────────────────────────────────────────────────────────────────────────────
describe("Vue extractor", function()
    local vue

    --- Helper: create a mock treesitter node
    --- @param node_type string
    --- @param opts table: { children, named_children, fields, text, range }
    local function make_node(node_type, opts)
        opts = opts or {}
        local node = {}
        node.type = function()
            return node_type
        end
        node.iter_children = function()
            local children = opts.children or {}
            local i = 0
            return function()
                i = i + 1
                return children[i]
            end
        end
        node.named_children = function()
            return opts.named_children or opts.children or {}
        end
        node.field = function(_, name)
            if opts.fields and opts.fields[name] then
                return opts.fields[name]
            end
            return {}
        end
        -- Store text/range for vim.treesitter mocks
        node._text = opts.text or node_type
        node._range = opts.range or 0
        return node
    end

    before_each(function()
        package.loaded["skipper.filetypes.vue"] = nil
        package.loaded["skipper.filetypes.utils"] = nil

        -- Mock vim.treesitter functions to use our node metadata
        _G.vim.treesitter.get_node_text = function(node)
            return node._text
        end
        _G.vim.treesitter.get_node_range = function(node)
            return node._range
        end
    end)

    it("should extract standard function declarations", function()
        -- Simulate: function myFunc() { ... }
        local name_node = make_node("identifier", { text = "myFunc" })
        local func_node = make_node("function_declaration", {
            fields = { name = { name_node } },
            children = {},
            range = 5,
        })

        -- Root with the function as child
        local root = make_node("program", { children = { func_node } })

        -- Mock get_parser to return a lang tree with JS injection
        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "javascript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("myFunc", functions[1].name)
        assert.are.equal(5, functions[1].line)
    end)

    it("should extract arrow functions from variable declarations", function()
        -- Simulate: const handler = () => { ... }
        local name_node = make_node("identifier", { text = "handler" })
        local arrow_fn = make_node("arrow_function", { children = {} })
        local declarator = make_node("variable_declarator", {
            fields = {
                name = { name_node },
                value = { arrow_fn },
            },
            children = {},
            range = 10,
        })
        local declaration = make_node("lexical_declaration", {
            children = { declarator },
        })

        local root = make_node("program", { children = { declaration } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "typescript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("handler", functions[1].name)
        assert.are.equal(10, functions[1].line)
    end)

    it("should extract computed() composable wrappers", function()
        -- Simulate: const fullName = computed(() => { ... })
        local name_node = make_node("identifier", { text = "fullName" })
        local callee_node = make_node("identifier", { text = "computed" })
        local call_expr = make_node("call_expression", {
            fields = { ["function"] = { callee_node } },
            children = {},
        })
        local declarator = make_node("variable_declarator", {
            fields = {
                name = { name_node },
                value = { call_expr },
            },
            children = {},
            range = 15,
        })
        local declaration = make_node("lexical_declaration", {
            children = { declarator },
        })

        local root = make_node("program", { children = { declaration } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "typescript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("fullName", functions[1].name)
        assert.are.equal(15, functions[1].line)
    end)

    it("should extract watch/watchEffect composables", function()
        -- Simulate: const cleanup = watch(() => { ... })
        local name_node = make_node("identifier", { text = "cleanup" })
        local callee_node = make_node("identifier", { text = "watch" })
        local call_expr = make_node("call_expression", {
            fields = { ["function"] = { callee_node } },
            children = {},
        })
        local declarator = make_node("variable_declarator", {
            fields = {
                name = { name_node },
                value = { call_expr },
            },
            children = {},
            range = 20,
        })
        local declaration = make_node("lexical_declaration", {
            children = { declarator },
        })

        local root = make_node("program", { children = { declaration } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "javascript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("cleanup", functions[1].name)
        assert.are.equal(20, functions[1].line)
    end)

    it("should extract lifecycle hooks (onMounted, etc.)", function()
        -- Simulate: onMounted(() => { ... })
        local callee_node = make_node("identifier", { text = "onMounted" })
        local call_expr = make_node("call_expression", {
            fields = { ["function"] = { callee_node } },
            children = {},
            range = 25,
        })
        local expr_stmt = make_node("expression_statement", {
            children = { call_expr },
        })

        local root = make_node("program", { children = { expr_stmt } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "typescript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("onMounted", functions[1].name)
        assert.are.equal(25, functions[1].line)
    end)

    it("should extract onBeforeUnmount lifecycle hook", function()
        local callee_node =
            make_node("identifier", { text = "onBeforeUnmount" })
        local call_expr = make_node("call_expression", {
            fields = { ["function"] = { callee_node } },
            children = {},
            range = 30,
        })
        local expr_stmt = make_node("expression_statement", {
            children = { call_expr },
        })

        local root = make_node("program", { children = { expr_stmt } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "typescript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("onBeforeUnmount", functions[1].name)
        assert.are.equal(30, functions[1].line)
    end)

    it("should NOT extract non-lifecycle call expressions", function()
        -- Simulate: doSomething(() => { ... })  -- not a lifecycle hook
        local callee_node = make_node("identifier", { text = "doSomething" })
        local call_expr = make_node("call_expression", {
            fields = { ["function"] = { callee_node } },
            children = {},
            range = 35,
        })
        local expr_stmt = make_node("expression_statement", {
            children = { call_expr },
        })

        local root = make_node("program", { children = { expr_stmt } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "javascript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(0, #functions)
    end)

    it("should ignore non-JS language trees (e.g. css)", function()
        local name_node = make_node("identifier", { text = "shouldIgnore" })
        local func_node = make_node("function_declaration", {
            fields = { name = { name_node } },
            children = {},
            range = 40,
        })
        local root = make_node("program", { children = { func_node } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    -- Only emit a CSS tree, no JS
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "css"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(0, #functions)
    end)

    it("should fallback to walking root when get_parser fails", function()
        -- Simulate: function fallbackFn() { ... }
        local name_node = make_node("identifier", { text = "fallbackFn" })
        local func_node = make_node("function_declaration", {
            fields = { name = { name_node } },
            children = {},
            range = 45,
        })
        local root = make_node("program", { children = { func_node } })

        _G.vim.treesitter.get_parser = function()
            error("no parser available")
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(1, #functions)
        assert.are.equal("fallbackFn", functions[1].name)
        assert.are.equal(45, functions[1].line)
    end)

    it("should extract multiple functions from a single tree", function()
        -- Simulate multiple declarations in one script block
        local name1 = make_node("identifier", { text = "funcA" })
        local func1 = make_node("function_declaration", {
            fields = { name = { name1 } },
            children = {},
            range = 2,
        })

        local name2 = make_node("identifier", { text = "funcB" })
        local arrow = make_node("arrow_function", { children = {} })
        local decl2 = make_node("variable_declarator", {
            fields = { name = { name2 }, value = { arrow } },
            children = {},
            range = 8,
        })
        local lex2 = make_node("lexical_declaration", {
            children = { decl2 },
        })

        local callee3 = make_node("identifier", { text = "onUpdated" })
        local call3 = make_node("call_expression", {
            fields = { ["function"] = { callee3 } },
            children = {},
            range = 14,
        })
        local expr3 = make_node("expression_statement", {
            children = { call3 },
        })

        local root = make_node("program", { children = { func1, lex2, expr3 } })

        _G.vim.treesitter.get_parser = function()
            return {
                for_each_tree = function(_, callback)
                    local tree = {
                        root = function()
                            return root
                        end,
                    }
                    local lang_tree = {
                        lang = function()
                            return "typescript"
                        end,
                    }
                    callback(tree, lang_tree)
                end,
            }
        end

        vue = require("skipper.filetypes.vue")
        local functions = {}
        vue.extract_functions(root, functions)

        assert.are.equal(3, #functions)
        assert.are.equal("funcA", functions[1].name)
        assert.are.equal(2, functions[1].line)
        assert.are.equal("funcB", functions[2].name)
        assert.are.equal(8, functions[2].line)
        assert.are.equal("onUpdated", functions[3].name)
        assert.are.equal(14, functions[3].line)
    end)
end)
