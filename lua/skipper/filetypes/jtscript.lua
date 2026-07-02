local M = {}
local utils = require("skipper.filetypes.utils")

function M.extract_functions(root, functions)
    utils.sail_through(root, functions, utils.catch_js_function)
end

return M
