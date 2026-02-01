## Create scratch file

Create temporary playground files effortlessly. Find them later without worrying about filenames or locations.

[Scratch Intro](https://github.com/LintaoAmons/scratch.nvim/assets/95092244/c1adff70-c8c5-4594-80e3-18d3e6b24d7a)

## Install & Config

```lua
-- use lazy.nvim
{
  "LintaoAmons/scratch.nvim",
  event = "VeryLazy",
}
```

<details>
<summary>Detailed Configuration</summary>

> Check my [neovim config](https://github.com/LintaoAmons/CoolStuffes/blob/main/nvim/.config/nvim/lua/plugins/editor-enhance/scratch.lua) as real life example

```lua
return {
  "LintaoAmons/scratch.nvim",
  event = "VeryLazy",
  dependencies = {
    {"ibhagwan/fzf-lua"}, --optional: if you want to use fzf-lua to pick scratch file. Recommended, since it will order the files by modification datetime desc. (require rg)
    {"nvim-telescope/telescope.nvim"}, -- optional: if you want to pick scratch file by telescope
    {"folke/snacks.nvim"}, -- optional: if you want to pick scratch file by snacks picker
    {"stevearc/dressing.nvim"} -- optional: to have the same UI shown in the GIF
  }
  config = function()
    require("scratch").setup({
      scratch_file_dir = vim.fn.stdpath("cache") .. "/scratch.nvim", -- where your scratch files will be put
      window_cmd = "edit", -- 'vsplit' | 'split' | 'edit' | 'tabedit' | 'rightbelow vsplit'
      -- fzf-lua it will order the files by modification datetime desc. (require rg)
      -- snacks.nvim is also supported with files/grep/multi mode toggle and orders by datetime desc. (require rg)
      file_picker = "fzflua", -- "fzflua" | "telescope" | "snacks" | nil
      filetypes = { "lua", "js", "sh", "ts" }, -- you can simply put filetype here
      filetype_details = { -- or, you can have more control here
        json = {}, -- empty table is fine
        ["project-name.md"] = {
          subdir = "project-name" -- group scratch files under specific sub folder
        },
        ["yaml"] = {},
        go = {
          subdir = "unique", -- isolate each scratch file in its own subdirectory
          filename = "main", -- the filename of the scratch file in the subdirectory
          content = { "package main", "", "func main() {", "  ", "}" },
          cursor = {
            location = { 4, 2 },
            insert_mode = true,
          },
        },
      },
      localKeys = {
        {
          filenameContains = { "sh" },
          LocalKeys = {
            {
              cmd = "<CMD>RunShellCurrentLine<CR>",
              key = "<C-r>",
              modes = { "n", "i", "v" },
            },
          },
        },
      },
      picker_keys = {
        delete = "<C-x>",      -- key to delete a scratch file from the picker
        toggle_mode = "<C-f>", -- toggle between files/grep/multi (snacks only)
      },
      picker_snacks_multi = false, -- true to start snacks picker in multi mode
      hooks = {
        {
          callback = function()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello", "world" })
          end,
        },
      },
    })
  end,
  event = "VeryLazy",
}
```

### Modify config at runtime, no need to restart nvim

To check your current configuration, simply type `:lua = vim.g.scratch_config`

And if you want to modify the config, for example add a new filetype, just call the `setup` function with your updated config again.

Or you can change the `vim.g.scratch_config` global variable directly

</details>

## Commands & Keymaps

All commands are started with `Scratch`, and no default keymappings.

| Command           | Description                                                                                             |
| ----------------- | ------------------------------------------------------------------------------------------------------- |
| `Scratch`         | Creates a new scratch file in the specified `scratch_file_dir` directory in your configuration.         |
| `ScratchWithName` | Allows the creation of a new scratch file with a user-specified filename, including the file extension. |
| `ScratchOpen`     | Opens an existing scratch file from the `scratch_file_dir`.                                             |
| `ScratchOpenFzf`  | Uses fuzzy finding to search through the contents of scratch files and open a selected file.            |

### Snacks multi mode

When using the snacks picker, you can set `picker_snacks_multi = true` to open `ScratchOpen` in multi mode, which combines file search and content grep in a single picker. `ScratchOpenFzf` is unaffected by this setting. You can toggle back to the classic file-only view at any time with `<C-f>` (or your custom `picker_keys.toggle_mode` key).

Keybinding recommendation:

```lua
vim.keymap.set("n", "<M-C-n>", "<cmd>Scratch<cr>")
vim.keymap.set("n", "<M-C-o>", "<cmd>ScratchOpen<cr>")
```

## CONTRIBUTING

Don't hesitate to ask me anything about the codebase if you want to contribute.

By [telegram](https://t.me/+ssgpiHyY9580ZWFl) or [微信: CateFat](https://lintao-index.pages.dev/assets/images/wechat-437d6c12efa9f89bab63c7fe07ce1927.png)

## Some Other Neovim Stuff

- [my neovim config](https://github.com/LintaoAmons/CoolStuffes/tree/main/nvim/.config/nvim)
- [scratch.nvim](https://github.com/LintaoAmons/scratch.nvim)
- [cd-project.nvim](https://github.com/LintaoAmons/cd-project.nvim)
- [bookmarks.nvim](https://github.com/LintaoAmons/bookmarks.nvim)
- [context-menu.nvim](https://github.com/LintaoAmons/context-menu.nvim)

---

<a href="https://lintao-index.pages.dev/getSupport/">
    <img src="https://img.shields.io/badge/sponsor-30363D?style=for-the-badge&logo=GitHub-Sponsors&logoColor=#white" />
</a>
