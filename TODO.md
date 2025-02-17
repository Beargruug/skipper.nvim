# Todo List

## Pending Tasks
- [ ] Task 1: adjust parser for handle 'no function' case.
- [ ] Task 2: move window creation to a separate file.
- [ ] Task 3: adjust default keymaps with <CR> binding and <ESC>.
- [ ] Task 4: add custom mappings to jump to function.
       e.q.  mappings['<CR>'] = { command = "blink to function"}
- [ ] Task 5: apply on_enter callback to set functions and line.name.
        e.g. vim.api.nvim_buf_set_lines(buf, 0, -1, false, {lines.name})
- [ ] Task 6: add store buffer option to window.

## Notes
- Note 1: set a keymap:

    vim.keymap.set("n", "<Esc>", function()
        M.close_window(win)
    end, {
        buffer = buf,
        noremap = true,
        silent = true,
    })

callback could look like this: ?
    if opts.on_enter then
        opts.on_enter(buf, win)
    end

    window return?
    { window = win, buffer = buf, close = vim.api.nvim_win_close(win, true) }

    handle mappings?
    loop over mappings and set them.

