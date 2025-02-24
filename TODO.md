# Todo List

## Pending Tasks
- [ ] Task 1: adjust parser for handle 'no function' and 'no parser' case.
- [ ] Task 2: move window creation to a separate file.
    - [ ] Task 3: handle opts vom ui.lua
    - [ ] Task 4: adjust default keymaps with <CR> binding and <ESC>.
- [ ] Task 5: add custom mappings to jump to function.
       e.q.  mappings['<CR>'] = { command = "blink to function"}
    - [ ] Task 6: add condition when mappings should be set.
- [ ] Task 7: apply on_enter callback to set functions and loop over line.name.
        e.g. vim.api.nvim_buf_set_lines(buf, 0, -1, false, {lines.name})
- [ ] Task 8: add types for variables.
- [ ] Task 9: add tests

## Notes
- Note 1: set a default keymap could look like this:

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

