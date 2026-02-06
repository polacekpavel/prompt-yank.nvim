local config = require('prompt-yank.config')
local util = require('prompt-yank.util')

local M = {}

local function pick_with_fzf(root, on_done)
  local ok, fzf = pcall(require, 'fzf-lua')
  if not ok then return false end

  fzf.files({
    cwd = root,
    prompt = 'Select files (TAB=select, ENTER=confirm)> ',
    file_icons = false,
    git_icons = false,
    color_icons = false,
    actions = {
      ['default'] = function(selected)
        if not selected or #selected == 0 then
          on_done({})
          return
        end
        local paths = {}
        for _, entry in ipairs(selected) do
          local path = util.trim(entry)
          if path ~= '' then table.insert(paths, path) end
        end
        on_done(paths)
      end,
    },
  })

  return true
end

local function pick_with_telescope(root, on_done)
  local ok = pcall(require, 'telescope')
  if not ok then return false end

  local builtin = require('telescope.builtin')
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  builtin.find_files({
    cwd = root,
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multi = picker:get_multi_selection()
        if vim.tbl_isempty(multi) then multi = { action_state.get_selected_entry() } end
        actions.close(prompt_bufnr)

        local paths = {}
        for _, entry in ipairs(multi) do
          local p = entry.path or entry.filename or entry.value or entry[1]
          if p then
            p = util.trim(p)
            if util.path_is_absolute(p) then p = util.path_relative(p, root) end
            table.insert(paths, p)
          end
        end

        on_done(paths)
      end)
      return true
    end,
  })

  return true
end

local function pick_with_input(root)
  local paths = {}
  while true do
    local input = vim.fn.input('Add file (empty to finish): ', '', 'file')
    input = util.trim(input)
    if input == '' then break end
    if util.path_is_absolute(input) then input = util.path_relative(input, root) end
    table.insert(paths, input)
  end
  return paths
end

function M.pick_files(opts, on_done)
  opts = opts or {}
  local conf = config.get()
  local preferred = (opts.preferred or conf.picker.preferred or 'auto'):lower()
  local root = opts.root or vim.fn.getcwd()

  if preferred == 'fzf-lua' or preferred == 'auto' then
    if pick_with_fzf(root, on_done) then return end
  end

  if preferred == 'telescope' or preferred == 'auto' then
    if pick_with_telescope(root, on_done) then return end
  end

  local paths = pick_with_input(root)
  on_done(paths)
end

return M
