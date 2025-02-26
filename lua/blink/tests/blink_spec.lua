local M = {}
package.loaded["nvim-treesitter.parsers"] = {
    get_parser = function()
        return {
            parse = function()
                return {}
            end,
        }
    end,
}

describe("UI Component", function()
    local ui = require("lua.blink.handle_window")
    local p = require("blink.parser")

    before_each(function()
        p.get_functions = function()
            return { name = "No functions found!" }
        end
    end)

    it(
        "should open a window with 'No functions found!' if no functions are found",
        function()
            ui.handle_window()

            local win = vim.api.nvim_get_current_win()
            assert.is_not_nil(win, "Window should be opened")

            local functions = p.get_functions()

            assert.are.same(
                { name = "No functions found!" },
                functions,
                "Buffer should contain 'No functions found!'"
            )
        end
    )

    it(
        "should open a window with function names if functions are found",
        function()
            p.get_functions = function()
                return {
                    { line = 2, name = "function1" },
                    { line = 5, name = "function2" },
                }
            end

            ui.handle_window()

            local win = vim.api.nvim_get_current_win()
            assert.is_not_nil(win, "Window should be opened")

            local functions = p.get_functions()
            assert.are.same(
                { line = 2, name = "function1" },
                functions[1],
                "Buffer should contain 'function1'"
            )
        end
    )
end)

return M
