local M = {}
local file_type = {}

local parsers = require("nvim-treesitter.parsers")

-- Function to extract functions from the current buffer
function M.get_functions()
  local functions = {}
  local parser = parsers.get_parser() -- Get the parser for the current buffer

  if not parser then
    print("Error: No parser found for this buffer.")
    return functions
  end

  local tree = parser:parse()
  if not tree then
    print("Error: No parse tree found.")
    return functions
  end

  local root = tree[1]:root() -- Get the root node of the AST

  file_type = vim.bo.filetype

  local children = root:named_children()

  if not children then
    print("No children found for root node.")
    return functions
  end

  for _, node in ipairs(children) do
    if file_type == "vue" then
      M.handle_vue_filetype(node, functions)
    end
    if
      file_type ~= "vue"
      and (
        node:type() == "function_declaration"
        or node:type() == "function_expression"
        or node:type() == "arrow_function"
        or node:type() == "method_definition"
        or node:type() == "async_function_declaration"
      )
    then
      local name_node = node:field("name")[1]

      if name_node then
        local func_name = vim.treesitter.get_node_text(name_node, 0)
        local line_number = vim.treesitter.get_node_range(node) -- Should be a table
        table.insert(functions, { name = func_name, line = line_number }) -- Adjust for expected table format
      end
    end
  end

  return functions
end

function M.jump_to_function_by_name()
  local buf = vim.api.nvim_get_current_buf()
  local functions = vim.api.nvim_buf_get_var(buf, "functions")
  local original_buf = vim.api.nvim_buf_get_var(buf, "original_buf")
  local line = vim.fn.line(".") -- Get current line in the functions window

  -- TODO: improve this
  local function_name = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
  local function_word = function_name:match("^(%S+)")

  for _, func in ipairs(functions) do
    if func.name == function_word then
      -- Close the plugin window first
      local current_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_close(current_win, true)

      vim.api.nvim_set_current_buf(original_buf)
      -- Get the total number of lines in the buffer
      local total_lines = vim.api.nvim_buf_line_count(original_buf)
      -- Search for the function name in the original buffer
      for line_number = 1, total_lines do
        local line_content = vim.api.nvim_buf_get_lines(original_buf, line_number - 1, line_number, false)[1] -- Get the line

        -- Check for function declarations
        if line_content then
          if
            line_content:find("function%s+" .. function_word .. "%s*%(")
            or line_content:find("const%s+" .. function_word .. "%s*=")
            or line_content:find(function_word .. "%s*%(([^)]*)%)%s*=>")
            or line_content:find("async%s+" .. function_word .. "%s*%(([^)]*)%)%s*=>")
          then
            -- Move the cursor to the found line
            vim.api.nvim_win_set_cursor(0, { line_number, 0 }) -- line_number is 1-based
            vim.cmd("normal! zz") -- Center the line
            return
          end
        end
      end
    end
  end
  print("Function not found: " .. line)
end

function M.handle_vue_filetype(node, functions)
  if node:type() == "script_element" then
    local script_children = node:named_children()
    for _, script_node in ipairs(script_children) do
      local raw_text = vim.treesitter.get_node_text(script_node, 0)
      -- Split the raw text into lines
      for line in raw_text:gmatch("[^\r\n]+") do
        -- Match normal functions
        for func_name in line:gmatch("function%s+([%w_]+)") do
          table.insert(functions, { name = func_name, line = "none" })
        end

        -- Match arrow functions
        for func_name in line:gmatch("const%s+([%w_]+)%s*=%s*%b()") do
          table.insert(functions, { name = func_name, line = "none" })
        end
        for func_name in line:gmatch("([%w_]+)%s*%(([^)]*)%)%s*=>") do
          table.insert(functions, { name = func_name, line = "none" })
        end

        -- Match async arrow functions
        for func_name in line:gmatch("const%s+async%s+([%w_]+)%s*%(([^)]*)%)%s*=>") do
          table.insert(functions, { name = func_name, line = "none" })
        end
        for func_name in line:gmatch("async%s+([%w_]+)%s*%(([^)]*)%)%s*=>") do
          table.insert(functions, { name = func_name, line = "none" })
        end
      end
    end
  end
end

-- Function to create a window showing the functions
function M.show_functions_window()
  local functions = M.get_functions()
  if #functions == 0 then
    print("No functions found!")
    return
  end

  local original_buf = vim.api.nvim_get_current_buf() -- Get the current buffer ID
  local buf = vim.api.nvim_create_buf(false, true) -- Create a new scratch buffer
  local lines = {}

  -- Prepare lines for the window
  for _, func in ipairs(functions) do
    table.insert(lines, func.name .. " (line " .. func.line .. ")")
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 50,
    height = math.min(#lines, 20), -- Limit height to 20 lines
    col = math.floor((vim.o.columns - 50) / 2),
    row = math.floor((vim.o.lines - 20) / 2),
    border = "rounded",
  })

  vim.api.nvim_win_set_option(win, "winblend", 20) -- Optional: Make the window semi-transparent
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe") -- Wipe buffer on close
  vim.api.nvim_win_set_option(win, "wrap", false) -- Disable wrapping

  -- Store function references for jumping
  vim.api.nvim_buf_set_var(buf, "functions", functions)
  vim.api.nvim_buf_set_var(buf, "original_buf", original_buf) -- Store original buffer ID

  -- mapping to jump to function on enter key inside the functions window
  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "<cr>",
    ':lua require("func_jumpr").jump_to_function()<cr>',
    { noremap = true, silent = true }
  )
end

-- Function to jump to the selected function
function M.jump_to_function()
  if file_type == "vue" then
    M.jump_to_function_by_name()
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local functions = vim.api.nvim_buf_get_var(buf, "functions")
  local original_buf = vim.api.nvim_buf_get_var(buf, "original_buf") -- Get original buffer ID
  local line = vim.fn.line(".") -- Get current line in the functions window

  -- Check if the line is within the valid range
  if functions[line] then
    local target_line = functions[line].line
    local total_lines = vim.api.nvim_buf_line_count(original_buf) -- Get total lines in the original buffer

    if target_line > 0 and target_line <= total_lines then
      -- Switch to the original buffer
      vim.api.nvim_set_current_buf(original_buf) -- Set the original buffer as current

      -- Find the window displaying the original buffer
      for _, win_id in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win_id) == original_buf then
          -- Set the cursor in the correct window
          vim.api.nvim_win_set_cursor(win_id, { target_line, 0 }) -- Move cursor to target line
          vim.cmd("normal! zz") -- Center the line
          break
        end
      end
    else
      print("Target line is out of range.")
    end
  else
    print("No function selected.")
  end

  -- Close the window after jumping
  vim.api.nvim_win_close(0, true)
end

return M, file_type
