<div align="center">

# Blink.nvim

A lightweight and efficient Neovim plugin to help you quickly navigate and manage your code with minimal keystrokes.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

![Blink](blink.jpeg)

## Status

Blink.nvim is under active development and is constantly being improved. Feedback, issue reports and pull requests are always welcome.

## Purpose of the plugin

When navigating between files or code sections, it’s easy to lose your overview or resort to annoying, repetitive keyboard shortcuts. Blink.nvim was developed to:

- **Fast Navigation:** Jump to frequently used functions with minimal keystrokes.
- **Intuitive Control:** A simple command structure that doesn’t interrupt your workflow.
- **Extensible Functionalities:** Easy integrations and customizations so that Blink.nvim fits perfectly into your workflow.

## Installation

Blink.nvim requires Neovim 0.5.0 or higher. Install the plugin with your preferred plugin manager. For example, with [vim-plug]:

```viml
Plug 'nvim-lua/plenary.nvim'  " Abhängigkeit, falls noch nicht installiert
Plug 'beargruug/blink.nvim'
```

## Add Keybindings

To use Blink.nvim, add the following keybindings to your `init.vim` or `init.lua`:

```viml
vim.keymap.set("n", "<leader>cf", "<cmd>:ShowFunctionsWindow<CR>")
```


