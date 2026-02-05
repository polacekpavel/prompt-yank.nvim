local util = require("prompt-yank.util")
local git = require("prompt-yank.git")

local M = {}

local function should_ignore(path, ignore)
  if not path or path == "" then
    return true
  end
  if path:match("^%.") or path:match("/%.") then
    return true
  end
  for _, dir in ipairs(ignore or {}) do
    if path == dir then
      return true
    end
    if path:find(dir .. "/", 1, true) == 1 then
      return true
    end
    if path:find("/" .. dir .. "/", 1, true) then
      return true
    end
  end
  return false
end

local function split_parts(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

local function insert_path(tree, parts)
  local current = tree
  for i, part in ipairs(parts) do
    if i == #parts then
      current[part] = true
    else
      current[part] = current[part] or {}
      current = current[part]
    end
  end
end

function M.build_tree(root, max_depth, ignore, max_files_fallback)
  local files = {}

  if git.is_git_repo(root) then
    local raw, code =
      util.system({ "git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard" })
    if code == 0 and raw and raw ~= "" then
      for file in raw:gmatch("[^\n]+") do
        file = util.trim(file)
        if file ~= "" and not should_ignore(file, ignore) then
          table.insert(files, file)
        end
      end
    end
  end

  if #files == 0 then
    local count = 0
    for name, ftype in vim.fs.dir(root, { depth = (max_depth or 3) + 1 }) do
      if ftype == "file" then
        local rel = name:gsub("^%./", "")
        if not should_ignore(rel, ignore) then
          table.insert(files, rel)
          count = count + 1
        end
        if max_files_fallback and count >= max_files_fallback then
          break
        end
      end
    end
  end

  local tree = {}
  for _, file in ipairs(files) do
    local parts = split_parts(file)
    if #parts <= (max_depth or 3) + 1 then
      insert_path(tree, parts)
    end
  end

  local lines = {}
  local function render(node, prefix)
    local dirs, files2 = {}, {}
    for k, v in pairs(node) do
      if type(v) == "table" then
        table.insert(dirs, k)
      else
        table.insert(files2, k)
      end
    end
    table.sort(dirs)
    table.sort(files2)

    local items = {}
    for _, k in ipairs(dirs) do
      table.insert(items, { name = k, value = node[k], is_dir = true })
    end
    for _, k in ipairs(files2) do
      table.insert(items, { name = k, value = node[k], is_dir = false })
    end

    for i, item in ipairs(items) do
      local is_last = i == #items
      local connector = is_last and "└── " or "├── "
      local display = item.is_dir and (item.name .. "/") or item.name
      table.insert(lines, prefix .. connector .. display)
      if item.is_dir then
        local next_prefix = prefix .. (is_last and "    " or "│   ")
        render(item.value, next_prefix)
      end
    end
  end

  render(tree, "")
  return table.concat(lines, "\n"), #lines
end

function M.render_path(filepath)
  local parts = split_parts(filepath)
  local out = {}
  for i, part in ipairs(parts) do
    local prefix = string.rep("│   ", i - 1)
    local is_file = i == #parts
    local display = is_file and part or (part .. "/")
    table.insert(out, prefix .. "└── " .. display)
  end
  return table.concat(out, "\n"), #out
end

return M
