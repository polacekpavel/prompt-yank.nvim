local M = {}

local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

local js_extensions = { '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs' }
local js_index_names = { 'index.ts', 'index.tsx', 'index.js', 'index.jsx' }

local function file_exists(path)
  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(path)
  return stat ~= nil
end

local function join_path(a, b)
  if vim.fs and vim.fs.joinpath then return vim.fs.joinpath(a, b) end
  return a .. '/' .. b
end

local function dirname(path) return vim.fn.fnamemodify(path, ':h') end

local function resolve_js_import(import_str, current_fullpath, root)
  if not import_str or import_str == '' then return nil end

  local base_dir
  if import_str:sub(1, 1) == '.' then
    base_dir = dirname(current_fullpath)
  else
    return nil
  end

  local candidate = join_path(base_dir, import_str)
  candidate = require('prompt-yank.util').normalize_path(candidate)

  if file_exists(candidate) then
    local uv = vim.uv or vim.loop
    local stat = uv.fs_stat(candidate)
    if stat and stat.type == 'directory' then
      for _, idx in ipairs(js_index_names) do
        local idx_path = join_path(candidate, idx)
        if file_exists(idx_path) then return idx_path end
      end
      return nil
    end
    return candidate
  end

  for _, ext in ipairs(js_extensions) do
    local with_ext = candidate .. ext
    if file_exists(with_ext) then return with_ext end
  end

  if file_exists(candidate) then return candidate end

  for _, idx in ipairs(js_index_names) do
    local idx_path = join_path(candidate, idx)
    if file_exists(idx_path) then return idx_path end
  end

  return nil
end

local function resolve_lua_require(module_str, current_fullpath, root)
  if not module_str or module_str == '' then return nil end

  local rel = module_str:gsub('%.', '/')

  local candidates = {
    join_path(root, rel .. '.lua'),
    join_path(root, rel .. '/init.lua'),
    join_path(root, 'lua/' .. rel .. '.lua'),
    join_path(root, 'lua/' .. rel .. '/init.lua'),
  }

  for _, path in ipairs(candidates) do
    if file_exists(path) then return path end
  end

  return nil
end

local function resolve_python_import(module_str, current_fullpath, root)
  if not module_str or module_str == '' then return nil end

  if module_str:sub(1, 1) == '.' then
    local base_dir = dirname(current_fullpath)
    local rest = module_str:sub(2):gsub('%.', '/')
    if rest == '' then return nil end
    local candidate = join_path(base_dir, rest .. '.py')
    if file_exists(candidate) then return candidate end
    candidate = join_path(base_dir, rest .. '/__init__.py')
    if file_exists(candidate) then return candidate end
    return nil
  end

  local rel = module_str:gsub('%.', '/')
  local candidates = {
    join_path(root, rel .. '.py'),
    join_path(root, rel .. '/__init__.py'),
  }
  for _, path in ipairs(candidates) do
    if file_exists(path) then return path end
  end

  return nil
end

local function extract_imports_treesitter(bufnr)
  if not vim.treesitter or not vim.treesitter.get_parser then return {} end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return {} end

  local trees = parser:parse()
  if not trees or not trees[1] then return {} end

  local ft = vim.bo[bufnr].filetype
  local imports = {}
  local seen = {}

  local root_node = trees[1]:root()

  local function add_import(text)
    if text and text ~= '' and not seen[text] then
      seen[text] = true
      table.insert(imports, text)
    end
  end

  local function strip_quotes(text)
    if not text then return nil end
    return text:match('^["\'](.-)["\'"]$') or text
  end

  local function visit(node)
    local node_type = node:type()

    if ft == 'lua' then
      if node_type == 'function_call' or node_type == 'call_expression' then
        local fn_node = nil
        for child in node:iter_children() do
          if child:type() == 'identifier' then
            fn_node = child
            break
          end
        end
        if fn_node then
          local fn_ok, fn_text = pcall(vim.treesitter.get_node_text, fn_node, bufnr)
          if fn_ok and fn_text == 'require' then
            for child in node:iter_children() do
              if child:type() == 'arguments' then
                for arg in child:iter_children() do
                  if arg:type() == 'string' then
                    local s_ok, s_text = pcall(vim.treesitter.get_node_text, arg, bufnr)
                    if s_ok and s_text then add_import(strip_quotes(s_text)) end
                  end
                end
              end
            end
          end
        end
      end
    end

    if
      ft == 'javascript'
      or ft == 'typescript'
      or ft == 'typescriptreact'
      or ft == 'javascriptreact'
    then
      if node_type == 'import_statement' then
        for child in node:iter_children() do
          if child:type() == 'string' or child:type() == 'string_fragment' then
            local s_ok, s_text = pcall(vim.treesitter.get_node_text, child, bufnr)
            if s_ok and s_text then add_import(strip_quotes(s_text)) end
          end
        end
      end

      if node_type == 'call_expression' then
        local fn_node = nil
        for child in node:iter_children() do
          if child:type() == 'identifier' then
            fn_node = child
            break
          end
        end
        if fn_node then
          local fn_ok, fn_text = pcall(vim.treesitter.get_node_text, fn_node, bufnr)
          if fn_ok and fn_text == 'require' then
            for child in node:iter_children() do
              if child:type() == 'arguments' then
                for arg in child:iter_children() do
                  if arg:type() == 'string' or arg:type() == 'string_fragment' then
                    local s_ok, s_text = pcall(vim.treesitter.get_node_text, arg, bufnr)
                    if s_ok and s_text then add_import(strip_quotes(s_text)) end
                  end
                end
              end
            end
          end
        end
      end
    end

    if ft == 'python' then
      if node_type == 'import_from_statement' then
        for child in node:iter_children() do
          if child:type() == 'dotted_name' or child:type() == 'relative_import' then
            local s_ok, s_text = pcall(vim.treesitter.get_node_text, child, bufnr)
            if s_ok and s_text then add_import(s_text) end
          end
        end
      end
    end

    for child in node:iter_children() do
      visit(child)
    end
  end

  visit(root_node)
  return imports
end

function M.resolve_import(import_str, current_fullpath, root, filetype)
  if filetype == 'lua' then return resolve_lua_require(import_str, current_fullpath, root) end

  if
    filetype == 'javascript'
    or filetype == 'typescript'
    or filetype == 'typescriptreact'
    or filetype == 'javascriptreact'
  then
    return resolve_js_import(import_str, current_fullpath, root)
  end

  if filetype == 'python' then return resolve_python_import(import_str, current_fullpath, root) end

  return nil
end

function M.imports_from_treesitter(bufnr, root)
  local current_fullpath = vim.api.nvim_buf_get_name(bufnr)
  if current_fullpath == '' then return {} end

  local ft = vim.bo[bufnr].filetype
  local raw_imports = extract_imports_treesitter(bufnr)
  local util = require('prompt-yank.util')

  local resolved = {}
  local seen = {}

  for _, imp in ipairs(raw_imports) do
    local fullpath = M.resolve_import(imp, current_fullpath, root, ft)
    if fullpath then
      fullpath = util.normalize_path(fullpath)
      local real = util.realpath(fullpath) or fullpath
      if not seen[real] and real ~= (util.realpath(current_fullpath) or current_fullpath) then
        if util.relpath_under_root(real, root) then
          seen[real] = true
          table.insert(resolved, real)
        end
      end
    end
  end

  return resolved
end

local function flatten_symbols(symbols, result)
  result = result or {}
  for _, sym in ipairs(symbols or {}) do
    table.insert(result, sym)
    if sym.children then flatten_symbols(sym.children, result) end
  end
  return result
end

function M.reference_files_from_lsp(bufnr, root, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 2000
  local max_symbols = opts.max_symbols or 30
  local max_files = opts.max_files or 10

  local clients = get_clients({ bufnr = bufnr })
  if #clients == 0 then return {} end

  local util = require('prompt-yank.util')
  local current_uri = vim.uri_from_bufnr(bufnr)

  local doc_params = { textDocument = { uri = current_uri } }
  local sym_results =
    vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', doc_params, timeout_ms)
  if not sym_results then return {} end

  local symbols = {}
  for _, res in pairs(sym_results) do
    if res.result then
      symbols = flatten_symbols(res.result)
      break
    end
  end

  if #symbols > max_symbols then
    local trimmed = {}
    for i = 1, max_symbols do
      trimmed[i] = symbols[i]
    end
    symbols = trimmed
  end

  local file_set = {}
  local file_list = {}

  for _, sym in ipairs(symbols) do
    if #file_list >= max_files then break end

    local pos = sym.selectionRange and sym.selectionRange.start
      or (sym.range and sym.range.start)
      or (sym.location and sym.location.range and sym.location.range.start)
    if not pos then goto continue end

    local ref_params = {
      textDocument = { uri = current_uri },
      position = pos,
      context = { includeDeclaration = false },
    }

    local ref_results =
      vim.lsp.buf_request_sync(bufnr, 'textDocument/references', ref_params, timeout_ms)
    if ref_results then
      for _, res in pairs(ref_results) do
        if res.result then
          for _, loc in ipairs(res.result) do
            local uri = loc.uri or loc.targetUri
            if uri and uri ~= current_uri then
              local filepath = vim.uri_to_fname(uri)
              filepath = util.normalize_path(filepath)
              local real = util.realpath(filepath) or filepath
              if not file_set[real] and util.relpath_under_root(real, root) then
                file_set[real] = true
                table.insert(file_list, real)
                if #file_list >= max_files then break end
              end
            end
          end
        end
      end
    end

    ::continue::
  end

  return file_list
end

function M.find_related_files(bufnr, root, opts)
  opts = opts or {}
  local max_files = opts.max_files or 10

  local util = require('prompt-yank.util')
  local current_fullpath = vim.api.nvim_buf_get_name(bufnr)
  local current_real = current_fullpath ~= ''
      and (util.realpath(current_fullpath) or current_fullpath)
    or nil

  local import_files = M.imports_from_treesitter(bufnr, root)
  local lsp_files = M.reference_files_from_lsp(bufnr, root, {
    timeout_ms = opts.timeout_ms or 2000,
    max_files = max_files,
    max_symbols = opts.max_symbols or 30,
  })

  local seen = {}
  local result = {}

  if current_real then seen[current_real] = true end

  for _, path in ipairs(import_files) do
    local real = util.realpath(path) or path
    if not seen[real] then
      seen[real] = true
      table.insert(result, real)
    end
  end

  for _, path in ipairs(lsp_files) do
    local real = util.realpath(path) or path
    if not seen[real] then
      seen[real] = true
      table.insert(result, real)
    end
  end

  if #result > max_files then
    local trimmed = {}
    for i = 1, max_files do
      trimmed[i] = result[i]
    end
    return trimmed
  end

  return result
end

return M
