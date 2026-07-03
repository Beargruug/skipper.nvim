-- config file for the plugin
local M = {}

M.options = {
    win_width = 60,
    win_height = 20,
    border = "single",
    title = "Skipper",
    filter_favorites = true,
    preview = true,
    preview_height = 20,
    preview_width = 80,
    preview_position = "right",
}

function M.set(opts)
    M.options = vim.tbl_extend("force", M.options, opts or {})
end

return M
