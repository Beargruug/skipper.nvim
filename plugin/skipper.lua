-- main modules for plugin registration
local skipper = require("skipper")

vim.api.nvim_create_user_command("ShowFunctionsWindow", function()
    skipper.show_functions_window()
end, {})
