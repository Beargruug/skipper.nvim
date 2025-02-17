<div align="center">

# Blink.nvim

A lightweight and efficient Neovim plugin to help you quickly navigate and manage your code with minimal keystrokes.

[![Lua](https://img.shields.io/badge/Lua-blue.svg?style=for-the-badge&logo=lua)](http://www.lua.org)
[![Neovim](https://img.shields.io/badge/Neovim%200.5+-green.svg?style=for-the-badge&logo=neovim)](https://neovim.io)

</div>

![Blink](blink.jpeg)

## Status

Blink.nvim befindet sich in aktiver Entwicklung und wird stetig verbessert. Feedback, Issue-Meldungen sowie Pull Requests sind immer willkommen.

## Zweck des Plugins

Beim Navigieren zwischen Dateien oder Codeabschnitten verliert man schnell den Überblick oder muss auf lästige, wiederkehrende Tastenkombinationen zurückgreifen. Blink.nvim wurde entwickelt, um:

- **Schnelles Navigieren:** Mit minimalen Eingaben zu oft genutzten Funktionen zu springen.
- **Intuitive Steuerung:** Eine einfache Befehlsstruktur, die den Arbeitsfluss nicht unterbricht.
- **Erweiterbare Funktionalitäten:** Leichte Integrationen und Anpassungen, sodass sich Blink.nvim perfekt in deinen Workflow einfügt.

## Installation

Blink.nvim benötigt Neovim 0.5.0 oder höher. Installiere das Plugin mit deinem bevorzugten Plugin-Manager. Zum Beispiel mit [vim-plug]:

```viml
Plug 'nvim-lua/plenary.nvim'  " Abhängigkeit, falls noch nicht installiert
Plug 'beargruug/blink.nvim'
```

## Add Keybindings

Füge die folgenden Tastenkombinationen zu deiner `init.vim` oder `init.lua` hinzu:

```viml
vim.keymap.set("n", "<leader>cf", "<cmd>:ShowFunctionsWindow<CR>")
```


