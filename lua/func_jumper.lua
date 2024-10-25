-- main module file
local func_jumper = require("func_jumper.module")

---@class Config
---@field opt string Your config option
local config = {}

---@class MyModule
local M = {}

---@type Config
M.config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.show_functions = function()
  return func_jumper.show_functions_window()
end

M.get_functions = function()
  return func_jumper.get_functions()
end

M.jump_to_function = function()
  return func_jumper.jump_to_function()
end

return M
