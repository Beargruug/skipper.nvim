-- entry point for the plugin
local M = {}

M.config = require("blink.config")
M.parser = require("blink.parser")
M.ui = require("blink.ui")
M.navigation = require("blink.navigation")

function M.setup(opts)
    M.config.set(opts)
end

M.show_functions_window = M.ui.show_functions_window

return M
