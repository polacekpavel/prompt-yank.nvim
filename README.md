## prompt-yank.nvim

Copy code with rich context (file paths, line numbers, language detection) formatted for pasting into LLM prompts.

Think of it as a **Copy for AI** button in Neovim.

![Selection example](doc/image_selection.jpg)

````text
`hooks/useWorkoutSettings.tsx#L62`
```tsx
  console.log(four_zero_four);
```

**Diagnostics:**
- L62: [error] Cannot find name 'four_zero_four'.
````

![File example](doc/image_file.jpg)

````text
`hooks/useWorkoutSettings.tsx#L48-L51`
```tsx
  } catch (error) {
    console.error("Error ensuring profile exists:", error);
    return false;
  }
```
````

![Multi-file example](doc/image_multi.jpg)

### Install (lazy.nvim)

```lua
{
  "polacekpavel/prompt-yank.nvim",
  cmd = { "PromptYank" },
  keys = {
    { "<Leader>yp", mode = { "n", "v" }, desc = "PromptYank: file/selection" },
    { "<Leader>ym", mode = "n", desc = "PromptYank: multi-file" },
    { "<Leader>yd", mode = { "n", "v" }, desc = "PromptYank: diff" },
    { "<Leader>yb", mode = { "n", "v" }, desc = "PromptYank: blame" },
    { "<Leader>ye", mode = "v", desc = "PromptYank: diagnostics" },
    { "<Leader>yt", mode = { "n", "v" }, desc = "PromptYank: tree" },
    { "<Leader>yr", mode = { "n", "v" }, desc = "PromptYank: remote URL" },
    { "<Leader>yf", mode = "n", desc = "PromptYank: function" },
  },
  opts = {},
  config = function(_, opts)
    require("prompt-yank").setup(opts)
  end,
}
```

### Setup

```lua
require("prompt-yank").setup({
  -- See defaults in: lua/prompt-yank/config.lua
})
```

### Commands

Everything is exposed via one command:

- `:PromptYank` (smart: range → selection, no range → file)
- `:PromptYank file|selection|function|multi|diff|blame|diagnostics|context|tree|remote`
- `:PromptYank format [name]`
- `:PromptYank formats`

### Checkhealth

Run:

- `:checkhealth prompt-yank`

### Default Keymaps

Set on `setup()` (disable with `keymaps = false`):

Normal mode:
- `<Leader>yp` copy file
- `<Leader>yf` copy function
- `<Leader>ym` copy multiple files
- `<Leader>yd` copy diff (current file)
- `<Leader>yb` copy blame (current file)
- `<Leader>yt` copy project tree
- `<Leader>yr` copy remote URL + code

Visual mode:
- `<Leader>yp` copy selection
- `<Leader>ye` copy diagnostics
- `<Leader>yd` copy selection + diff
- `<Leader>yb` copy selection blame
- `<Leader>yt` copy tree path + selection

### Output Example

````text
`src/main.lua#L10-L20`
```lua
-- code here
```
````

### Notes

- No required dependencies (pure Lua).
- Git features require `git` available on `$PATH`.
- Multi-file picker prefers `fzf-lua`, then `telescope`, then a builtin input fallback.

### Development

- `make lint` checks formatting.
- `make test` runs headless tests and requires Plenary.
- Provide Plenary with `make deps` or set `PLENARY_DIR` to an existing checkout.

### Security / Safety

- All git invocations use list-form `vim.fn.system({ ... })` (no shell parsing).
- `:PromptYank remote` strips embedded credentials from HTTPS remotes (e.g. `https://token@…`); prefer SSH or credential helpers instead of storing tokens in remotes.
- With `path_style="relative"`, output never includes absolute local paths (files outside the root fall back to `:.'` style paths like `../…`).
- Git/tree features refuse to generate repo context for files outside the detected project root (prevents bogus URLs / absolute-path trees).
- Multi-file yank skips common sensitive files by default and will not copy files outside the detected project root.
- Large files/diffs prompt for confirmation before copying.
