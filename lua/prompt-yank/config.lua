local M = {}

M.defaults = {
  output_style = 'markdown',
  format = 'default',
  formats = {
    default = '`{filepath}{lines_hash}`\n```{lang}\n{code}\n```',
    minimal = '```{lang}\n{code}\n```\n<!-- {filepath}{lines_hash} -->',
    xml = '<file path="{filepath}" lines="{lines_plain}" language="{lang}">\n{code}\n</file>',
    claude = '<file path="{filepath}" lines="{lines_plain}" language="{lang}">\n<code>\n{code}\n</code>\n</file>',
  },
  templates = {
    diagnostics = '{code_block}\n\n**Diagnostics:**\n{diagnostics}',
    diff_file = '`{filepath}` (uncommitted changes)\n```diff\n{diff}\n```',
    diff_with_selection = '`{filepath}{lines_hash}`\n\n**Current code:**\n```{lang}\n{code}\n```\n\n**File diff:**\n```diff\n{diff}\n```',
    blame_file = '`{filepath}` (with git blame)\n```{lang}\n{blame}\n```',
    blame_selection = '`{filepath}{lines_hash}` (with git blame)\n```{lang}\n{blame}\n```',
    tree_full = '**Project: {project_name}**\n```\n{project_tree}\n```',
    tree_with_selection = '**Project: {project_name}**\n```\n{project_tree}\n```\n\n{code_block}',
    remote_with_code = '`{filepath}{lines_hash}`\n{remote_url}\n\n```{lang}\n{code}\n```',
    context = '`{filepath}{lines_hash}` (with {context_lines} lines context)\n```{lang}\n{code}\n```',
    function_named = '`{filepath}{lines_hash}` (function: {symbol_name})\n```{lang}\n{code}\n```',
    definitions_header = '\n\n---\n\n**Referenced Definitions:**\n\n',
    definitions_deep_header = '\n\n---\n\n**Referenced Definitions (deep):**\n\n',
    definition_item = '`{filepath}#L{start_line}-L{end_line}` (definition: {name})\n```{lang}\n{code}\n```',
    multi_sep = '\n\n',
  },
  xml_templates = {
    diagnostics = '{code_block}\n<diagnostics>\n{diagnostics}\n</diagnostics>',
    diff_file = '<diff path="{filepath}" type="uncommitted">\n{diff}\n</diff>',
    diff_with_selection = '<file path="{filepath}" lines="{lines_plain}" language="{lang}">\n{code}\n</file>\n<diff path="{filepath}" type="uncommitted">\n{diff}\n</diff>',
    blame_file = '<blame path="{filepath}" language="{lang}">\n{blame}\n</blame>',
    blame_selection = '<blame path="{filepath}" lines="{lines_plain}" language="{lang}">\n{blame}\n</blame>',
    tree_full = '<project name="{project_name}">\n{project_tree}\n</project>',
    tree_with_selection = '<project name="{project_name}">\n{project_tree}\n</project>\n\n{code_block}',
    remote_with_code = '<file path="{filepath}" lines="{lines_plain}" language="{lang}" remote="{remote_url}">\n{code}\n</file>',
    context = '<file path="{filepath}" lines="{lines_plain}" language="{lang}" context_lines="{context_lines}">\n{code}\n</file>',
    function_named = '<function name="{symbol_name}" path="{filepath}" lines="{lines_plain}" language="{lang}">\n{code}\n</function>',
    definitions_header = '\n<definitions>\n',
    definitions_deep_header = '\n<definitions type="deep">\n',
    definitions_footer = '</definitions>',
    definition_item = '<definition name="{name}" path="{filepath}" lines="{start_line}-{end_line}" language="{lang}">\n{code}\n</definition>',
    multi_sep = '\n\n',
  },
  path_style = 'relative',
  root = { strategy = 'git_or_cwd' },
  register = '+',
  notify = true,
  context_lines = 5,
  tree = {
    max_depth = 3,
    ignore = { 'node_modules', '.git', 'dist', 'build' },
    max_files_fallback = 200,
  },
  limits = {
    max_file_bytes = 2 * 1024 * 1024,
    max_diff_bytes = 2 * 1024 * 1024,
  },
  lang_map = {
    typescript = 'typescript',
    typescriptreact = 'tsx',
    javascript = 'javascript',
    javascriptreact = 'jsx',
    python = 'python',
    lua = 'lua',
    rust = 'rust',
    go = 'go',
    swift = 'swift',
    c = 'c',
    cpp = 'cpp',
    java = 'java',
    ruby = 'ruby',
    php = 'php',
    html = 'html',
    css = 'css',
    scss = 'scss',
    json = 'json',
    yaml = 'yaml',
    toml = 'toml',
    markdown = 'markdown',
    sh = 'bash',
    bash = 'bash',
    zsh = 'zsh',
    fish = 'fish',
    vim = 'vim',
    sql = 'sql',
    graphql = 'graphql',
  },
  ext_map = {
    ts = 'typescript',
    tsx = 'tsx',
    js = 'javascript',
    jsx = 'jsx',
    py = 'python',
    lua = 'lua',
    rs = 'rust',
    go = 'go',
    swift = 'swift',
    c = 'c',
    cpp = 'cpp',
    h = 'c',
    json = 'json',
    yaml = 'yaml',
    yml = 'yaml',
    toml = 'toml',
    md = 'markdown',
    sh = 'bash',
    bash = 'bash',
    zsh = 'zsh',
    fish = 'fish',
    html = 'html',
    css = 'css',
    scss = 'scss',
    sql = 'sql',
    graphql = 'graphql',
  },
  sensitive_patterns = {
    '%.env$',
    '%.env%.',
    '%.envrc$',
    'id_rsa',
    'id_ed25519',
    'id_ecdsa',
    'id_dsa',
    '%.pem$',
    '%.key$',
    '%.p12$',
    '%.pfx$',
    'secret',
    'credential',
    'password',
    '%.sqlite$',
    '%.kdbx$',
    '%.tfstate$',
    '%.tfstate%.backup$',
    '%.npmrc$',
    '%.pypirc$',
    '%.netrc$',
    '%.git%-credentials$',
  },
  picker = { preferred = 'auto' },
  git = { remote = 'origin' },
  keymaps = {
    copy_selection = '<Leader>yp',
    copy_file = '<Leader>yp',
    copy_function = '<Leader>yf',
    copy_multi = '<Leader>ym',
    copy_diff = '<Leader>yd',
    copy_diagnostics = '<Leader>ye',
    copy_context = '<Leader>yc',
    copy_tree = '<Leader>yt',
    copy_blame = '<Leader>yb',
    copy_remote = '<Leader>yr',
    copy_with_definitions = '<Leader>yl',
    copy_with_definitions_deep = '<Leader>yL',
  },
}

M._config = nil

local function deep_copy(value) return vim.deepcopy(value) end

local function deep_merge(base, override) return vim.tbl_deep_extend('force', base, override or {}) end

function M.setup(opts)
  M._config = deep_merge(deep_copy(M.defaults), opts or {})

  if M._config.output_style == 'xml' then
    if not opts or opts.format == nil then M._config.format = 'xml' end
  end

  return M._config
end

function M.get()
  if not M._config then M.setup({}) end
  return M._config
end

function M.set_format(name)
  local conf = M.get()
  if type(name) ~= 'string' or name == '' then
    return false, 'format name must be a non-empty string'
  end
  if conf.formats[name] == nil then return false, ('unknown format: %s'):format(name) end
  conf.format = name
  return true
end

function M.set_output_style(style)
  local conf = M.get()
  if type(style) ~= 'string' or style == '' then
    return false, 'output_style must be a non-empty string'
  end
  if style ~= 'markdown' and style ~= 'xml' then
    return false, ('unknown output_style: %s (expected "markdown" or "xml")'):format(style)
  end
  conf.output_style = style
  if style == 'xml' then
    conf.format = 'xml'
  else
    conf.format = 'default'
  end
  return true
end

function M.resolve_template(name)
  local conf = M.get()
  if conf.output_style == 'xml' then
    local xml_tpl = conf.xml_templates and conf.xml_templates[name]
    if xml_tpl ~= nil then return xml_tpl end
  end
  return conf.templates and conf.templates[name]
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
