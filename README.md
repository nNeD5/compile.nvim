# compile.nvim

Compile command inside neovim and see output in buffer.

https://github.com/user-attachments/assets/406ac815-c319-4d43-95bf-776633e42b1b

---

# Features

- async: you can use your editor while command is running. You can even use `watch` commands.
- auto-scroll: scroll your compile buffer to bottom as command output
- colors with [baleia.nvim](https://github.com/m00qek/baleia.nvim)
- changed behavior of gf, gF key binds: they will not open file inside compilation window, instead in previous(`<C-w>p`) one

# Installation

[lazy.nvim](https://lazy.folke.io/)
```lua
{
  "nNeD5/compile.nvim",
  dependencies = { "m00qek/baleia.nvim" },
  opts = {},
  config = function(_, opts)
    compile = require("compile")
    compile.setup(opts)
    vim.keymap.set("n", "<leader>r", compile.compile)
    vim.keymap.set("n", "<leader>R", compile.set_cmd)
    vim.keymap.set("n", "<C-c>", compile.stop)
  end
}
```

# Usage

- lua
```lua
:lua require("compile").compile()   -- start compilation command (ask to set command if none)
:lua require("compile").set_cmd()   -- change compilation command
:lua require("compile").stop()      -- stop current job
```
- Vim commands
```vim
:Compile        " start compilation command (ask to set command if none)
:CompileSetCmd  " change compilation command
:CompileStop    " stop current job
```
- or use key binds `<leader>r` `<leader>R` `<C-c>` from [Installation](#installation) section

# Setup

There is no setup options for now.
