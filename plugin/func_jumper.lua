local func_jumper = require("func_jumper")

vim.api.nvim_create_user_command("ShowFunctions", func_jumper.show_functions, {})
vim.api.nvim_create_user_command("GetFunctions", func_jumper.get_functions, {})
