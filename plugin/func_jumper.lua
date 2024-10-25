local func_jumpr = require("func_jumpr")

vim.api.nvim_create_user_command("ShowFunctions", func_jumpr.show_functions, {})
vim.api.nvim_create_user_command("GetFunctions", func_jumpr.get_functions, {})
