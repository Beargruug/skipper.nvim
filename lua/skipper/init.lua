-- entry point for the plugin
local M = {}

M.config = require("skipper.config")
M.parser = require("skipper.parser")
M.ui = require("skipper.handle_window")
M.navigation = require("skipper.navigation")

function M.setup(opts)
    M.config.set(opts)
end

M.show_functions_window = M.ui.handle_window

return M
