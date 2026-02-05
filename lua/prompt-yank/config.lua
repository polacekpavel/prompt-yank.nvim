local M = {}

M.defaults = {
  format = "default",
  formats = {
    default = "`{filepath}{lines_hash}`\n```{lang}\n{code}\n```",
    minimal = "```{lang}\n{code}\n```\n<!-- {filepath}{lines_hash} -->",
    xml = '<file path="{filepath}" lines="{lines_plain}" language="{lang}">\n{code}\n</file>',
    claude = '<file path="{filepath}" lines="{lines_plain}" language="{lang}">\n<code>\n{code}\n</code>\n</file>',
  },
  templates = {
    diagnostics = "{code_block}\n\n**Diagnostics:**\n{diagnostics}",
    diff_file = "`{filepath}` (uncommitted changes)\n```diff\n{diff}\n```",
    diff_with_selection = "`{filepath}{lines_hash}`\n\n**Current code:**\n```{lang}\n{code}\n```\n\n**File diff:**\n```diff\n{diff}\n```",
    blame_file = "`{filepath}` (with git blame)\n```{lang}\n{blame}\n```",
    blame_selection = "`{filepath}{lines_hash}` (with git blame)\n```{lang}\n{blame}\n```",
    tree_full = "**Project: {project_name}**\n```\n{project_tree}\n```",
    tree_with_selection = "**Project: {project_name}**\n```\n{project_tree}\n```\n\n{code_block}",
    remote_with_code = "`{filepath}{lines_hash}`\n{remote_url}\n\n```{lang}\n{code}\n```",
    context = "`{filepath}{lines_hash}` (with {context_lines} lines context)\n```{lang}\n{code}\n```",
    function_named = "`{filepath}{lines_hash}` (function: {symbol_name})\n```{lang}\n{code}\n```",
    multi_sep = "\n\n",
  },
  path_style = "relative",
  root = { strategy = "git_or_cwd" },
  register = "+",
  notify = true,
  context_lines = 5,
  tree = {
    max_depth = 3,
    ignore = { "node_modules", ".git", "dist", "build" },
    max_files_fallback = 200,
  },
  limits = {
    max_file_bytes = 2 * 1024 * 1024,
    max_diff_bytes = 2 * 1024 * 1024,
  },
  lang_map = {
    typescript = "typescript",
    typescriptreact = "tsx",
    javascript = "javascript",
    javascriptreact = "jsx",
    python = "python",
    lua = "lua",
    rust = "rust",
    go = "go",
    swift = "swift",
    c = "c",
    cpp = "cpp",
    java = "java",
    ruby = "ruby",
    php = "php",
    html = "html",
    css = "css",
    scss = "scss",
    json = "json",
    yaml = "yaml",
    toml = "toml",
    markdown = "markdown",
    sh = "bash",
    bash = "bash",
    zsh = "zsh",
    fish = "fish",
    vim = "vim",
    sql = "sql",
    graphql = "graphql",
  },
  ext_map = {
    ts = "typescript",
    tsx = "tsx",
    js = "javascript",
    jsx = "jsx",
    py = "python",
    lua = "lua",
    rs = "rust",
    go = "go",
    swift = "swift",
    c = "c",
    cpp = "cpp",
    h = "c",
    json = "json",
    yaml = "yaml",
    yml = "yaml",
    toml = "toml",
    md = "markdown",
    sh = "bash",
    bash = "bash",
    zsh = "zsh",
    fish = "fish",
    html = "html",
    css = "css",
    scss = "scss",
    sql = "sql",
    graphql = "graphql",
  },
  sensitive_patterns = {
    "%.env$",
    "%.env%.",
    "%.envrc$",
    "id_rsa",
    "id_ed25519",
    "id_ecdsa",
    "id_dsa",
    "%.pem$",
    "%.key$",
    "%.p12$",
    "%.pfx$",
    "secret",
    "credential",
    "password",
    "%.sqlite$",
    "%.kdbx$",
    "%.tfstate$",
    "%.tfstate%.backup$",
    "%.npmrc$",
    "%.pypirc$",
    "%.netrc$",
    "%.git%-credentials$",
  },
  picker = { preferred = "auto" },
  git = { remote = "origin" },
  keymaps = {
    copy_selection = "<Leader>yp",
    copy_file = "<Leader>yp",
    copy_function = "<Leader>yf",
    copy_multi = "<Leader>ym",
    copy_diff = "<Leader>yd",
    copy_diagnostics = "<Leader>ye",
    copy_context = "<Leader>yc",
    copy_tree = "<Leader>yt",
    copy_blame = "<Leader>yb",
    copy_remote = "<Leader>yr",
  },
}

M._config = nil

local function deep_copy(value)
  return vim.deepcopy(value)
end

local function deep_merge(base, override)
  return vim.tbl_deep_extend("force", base, override or {})
end

function M.setup(opts)
  M._config = deep_merge(deep_copy(M.defaults), opts or {})
  return M._config
end

function M.get()
  if not M._config then
    M.setup({})
  end
  return M._config
end

function M.set_format(name)
  local conf = M.get()
  if type(name) ~= "string" or name == "" then
    return false, "format name must be a non-empty string"
  end
  if conf.formats[name] == nil then
    return false, ("unknown format: %s"):format(name)
  end
  conf.format = name
  return true
end

function M.list_formats()
  local conf = M.get()
  local keys = {}
  for k in pairs(conf.formats or {}) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

return M
