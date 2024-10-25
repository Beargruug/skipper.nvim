# func-jumper.nvim

`func-jumper.nvim` is a Neovim plugin designed to enhance your coding workflow by allowing you to quickly jump to function declarations within your code. It leverages Neovim's built-in functionality for effective code parsing, making navigation seamless and intuitive.

## Features

- **Function Navigation**: Easily navigate to function declarations with a simple command.
- **Support for Multiple Languages**: Currently supports languages like Lua and Vue. (Note: Ruby and some other languages are not yet supported.)
- **Integration with Telescope**: Integration coming soon.

## Installation

You can install `func-jumper.nvim` using your favorite package manager.

### Using Lazy.nvim
To install `func-jumper.nvim` with [Lazy.nvim](https://github.com/folke/lazy.nvim), add the following line to your Lazy configuration:

```lua
{
  'beargruug/func-jumper.nvim',
}
```

## Usage
1. Open a file in a supported language.
2. Use the command `:ShowFunctions` to invoke the function navigation feature.
3. Select a function from the list or use the search feature to find it quickly.

## Key Bindings
You can configure key bindings to make navigation even easier. For example:

```lua
vim.api.nvim_set_keymap('n', '<leader>cf', ':ShowFunctions<CR>', { noremap = true, silent = true })
```
# Supported Languages
Currently, `func-jumper.nvim` supports:

- Vue
- lua

## Note
Some languages, such as Ruby or Typescript, are not yet supported. Contributions to extend support for additional languages are welcome!

## Contributing
Contributions are welcome! If you’d like to contribute, please fork the repository and submit a pull request. Be sure to adhere to the project's coding standards and guidelines.

## License
This project is licensed under the MIT License. See the LICENSE file for details.
