<div align="center">

# Skipper.nvim

A lightweight Neovim plugin for fast function navigation using Tree-sitter.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

![Skipper](skipper.png)

## Demo

<https://github.com/user-attachments/assets/b539c3cb-654c-435e-98ed-11bc93823e1a>

## Features

- **Fast function navigation** - Open a popup window listing all functions in the current file
- **Tree-sitter powered** - Accurate parsing across multiple languages
- **Jump to definition** - Select a function and instantly jump to its location
- **Favorites** - Pin frequently used functions to the top of the list
- **Filter favorites** - Optionally hide favorited functions from the main list
- **Minimal UI** - Clean floating window that doesn't interrupt your workflow
- **Customizable** - Configure window size, border style, and title
- **Generic language support** - Works with any language that has a Tree-sitter parser

## Supported Languages

| Language | File Types | Extractor |
|----------|------------|-----------|
| JavaScript | `.js` | Dedicated (handles exports, arrow functions, object methods) |
| TypeScript | `.ts` | Dedicated (shared with JS) |
| React (JSX/TSX) | `.jsx`, `.tsx` | Dedicated (shared with JS) |
| Vue | `.vue` | Dedicated (SFC support) |
| All others | Any | Generic (matches any node with "function" or "method" in its type) |

The generic extractor covers Lua, Go, Python, Ruby, Rust, C, Java, and any other language with a Tree-sitter parser installed.

## Requirements

- Neovim >= 0.5.0
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with parsers installed for your languages

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "beargruug/skipper.nvim",
    config = function()
        require("skipper").setup()
    end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'beargruug/skipper.nvim'
```

Then add to your config:

```lua
require("skipper").setup()
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "beargruug/skipper.nvim",
    config = function()
        require("skipper").setup()
    end,
}
```

## Configuration

Skipper.nvim comes with sensible defaults, but you can customize it:

```lua
require("skipper").setup({
    win_width = 120,        -- Width of the floating window
    win_height = 20,        -- Height of the floating window
    border = "single",      -- Border style ("single", "double", "rounded", "none")
    title = "Skipper",      -- Window title
    filter_favorites = true, -- Hide favorited functions from the main list
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:ShowFunctionsWindow` | Open the function navigation window |

### Keymaps

Add a keymap to quickly open the function window:

```lua
vim.keymap.set("n", "<leader>cf", "<cmd>ShowFunctionsWindow<CR>", { desc = "Show functions" })
```

Or call the Lua API directly:

```lua
vim.keymap.set("n", "<leader>cf", function()
    require("skipper").show_functions_window()
end, { desc = "Show functions" })
```

### Window Controls

Once the function window is open:

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate up/down the function list |
| `<CR>` | Jump to the selected function |
| `a` | Toggle favorite |
| `x` | Remove favorite (in favorites section) |
| `q` | Close the window |
| `<Esc>` | Close the window |
| `<C-c>` | Close the window |
| `?` | Toggle help menu |

### Favorites

Functions can be pinned as favorites. Favorites appear at the top of the list, separated from the main function list. When `filter_favorites = true` (default), favorited functions are hidden from the main list to avoid duplication.

## Health Check

Run `:checkhealth skipper` to verify your setup. It checks for Tree-sitter availability and installed parsers.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Status

Skipper.nvim is under active development. Feedback, issue reports, and pull requests are always welcome.

## License

MIT
