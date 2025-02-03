-- main modules for plugin registration
local blink = require("blink")

vim.api.nvim_create_user_command("ShowFunctionsWindow", function()
    blink.show_functions_window()
end, {})
