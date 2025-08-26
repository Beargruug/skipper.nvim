-- config file for the plugin
local M = {}

M.options = {
    win_width = 120,
    win_height = 20,
    border = "single",
    title = "Skipper",
}

function M.set(opts)
    M.options = vim.tbl_extend("force", M.options, opts or {})
end

return M
