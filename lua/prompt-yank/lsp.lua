local M = {}

local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

local identifier_types = {
  identifier = true,
  type_identifier = true,
  field_identifier = true,
  property_identifier = true,
  shorthand_property_identifier = true,
  shorthand_property_identifier_pattern = true,
  jsx_identifier = true,
  private_property_identifier = true,
  namespace_identifier = true,
}

local skip_names = {
  ['true'] = true,
  ['false'] = true,
  ['null'] = true,
  ['undefined'] = true,
  ['this'] = true,
  ['super'] = true,
}

local function get_identifiers_in_range(bufnr, start_line, end_line)
  if not vim.treesitter or not vim.treesitter.get_parser then return {} end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return {} end

  local trees = parser:parse()
  if not trees or not trees[1] then return {} end

  local identifiers = {}
  local seen = {}

  local function collect_from_tree(tree)
    local root = tree:root()

    local function visit(node)
      local sr, sc, er, _ = node:range()

      if sr > end_line - 1 then return end
      if er < start_line - 1 then return end

      local node_type = node:type()

      if identifier_types[node_type] then
        local text_ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
        if text_ok and text and text ~= '' and not skip_names[text] and not seen[text] then
          seen[text] = true
          table.insert(identifiers, { name = text, line = sr, col = sc })
        end
      end

      for child in node:iter_children() do
        visit(child)
      end
    end

    visit(root)
  end

  for _, tree in ipairs(trees) do
    collect_from_tree(tree)
  end

  return identifiers
end

local function make_position_params(bufnr, line, col)
  local row = line
  local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

  local clients = get_clients({ bufnr = bufnr })
  local offset_encoding = 'utf-16'
  for _, client in ipairs(clients) do
    if client.offset_encoding then
      offset_encoding = client.offset_encoding
      break
    end
  end

  local character = col
  if offset_encoding ~= 'utf-8' and col > 0 and col <= #line_text then
    local ok, result = pcall(function()
      if vim.str_utfindex then
        return vim.str_utfindex(line_text, offset_encoding, col, false)
      elseif vim.lsp.util._str_utfindex_enc then
        return vim.lsp.util._str_utfindex_enc(line_text, col, offset_encoding)
      end
      return col
    end)
    if ok and result then character = result end
  end

  return {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row, character = character },
  }
end

local function try_lsp_method(bufnr, method, params, timeout_ms)
  local results = vim.lsp.buf_request_sync(bufnr, method, params, timeout_ms)
  if not results then return nil end

  for _, res in pairs(results) do
    if res.result then
      local locations = res.result
      if type(locations) == 'table' then
        if locations[1] then
          return locations[1]
        elseif locations.uri or locations.targetUri then
          return locations
        end
      end
    end
  end

  return nil
end

local function lsp_get_definition(bufnr, line, col, timeout_ms)
  timeout_ms = timeout_ms or 2000

  local clients = get_clients({ bufnr = bufnr })
  if #clients == 0 then return nil end

  local params = make_position_params(bufnr, line, col)

  local methods = {
    'textDocument/definition',
    'textDocument/typeDefinition',
    'textDocument/implementation',
  }

  for _, method in ipairs(methods) do
    local result = try_lsp_method(bufnr, method, params, timeout_ms)
    if result then return result end
  end

  return nil
end

local function location_to_info(location)
  local uri = location.uri or location.targetUri
  local range = location.range or location.targetSelectionRange or location.targetRange

  if not uri or not range then return nil end

  local filepath = vim.uri_to_fname(uri)
  local start_line = (range.start and range.start.line or 0) + 1
  local end_line = (range['end'] and range['end'].line or start_line - 1) + 1

  return {
    filepath = filepath,
    start_line = start_line,
    end_line = end_line,
  }
end

local function read_definition_code(filepath, start_line)
  local ok, lines = pcall(vim.fn.readfile, filepath)
  if not ok or not lines then return nil, nil end

  if not vim.treesitter then
    local end_line = math.min(start_line + 20, #lines)
    local code_lines = {}
    for i = start_line, end_line do
      table.insert(code_lines, lines[i])
    end
    return table.concat(code_lines, '\n'), end_line
  end

  local ft = vim.filetype.match({ filename = filepath })
  if not ft then
    local end_line = math.min(start_line + 20, #lines)
    local code_lines = {}
    for i = start_line, end_line do
      table.insert(code_lines, lines[i])
    end
    return table.concat(code_lines, '\n'), end_line
  end

  local content = table.concat(lines, '\n')
  local parser_ok, parser = pcall(vim.treesitter.get_string_parser, content, ft)
  if not parser_ok or not parser then
    local end_line = math.min(start_line + 20, #lines)
    local code_lines = {}
    for i = start_line, end_line do
      table.insert(code_lines, lines[i])
    end
    return table.concat(code_lines, '\n'), end_line
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    local end_line = math.min(start_line + 20, #lines)
    local code_lines = {}
    for i = start_line, end_line do
      table.insert(code_lines, lines[i])
    end
    return table.concat(code_lines, '\n'), end_line
  end

  local root = trees[1]:root()
  local target_row = start_line - 1
  local node = root:named_descendant_for_range(target_row, 0, target_row, 0)

  local container_types = {
    function_declaration = true,
    function_definition = true,
    function_item = true,
    ['function'] = true,
    method_definition = true,
    method_declaration = true,
    class_declaration = true,
    class_definition = true,
    struct_item = true,
    enum_item = true,
    impl_item = true,
    trait_item = true,
    interface_declaration = true,
    type_alias_declaration = true,
    lexical_declaration = true,
    variable_declaration = true,
    const_declaration = true,
    let_declaration = true,
    export_statement = true,
  }

  while node do
    if container_types[node:type()] then
      local sr, _, er, ec = node:range()
      local actual_end = er + 1
      if ec == 0 and er > sr then actual_end = er end
      local code_lines = {}
      for i = sr + 1, actual_end do
        table.insert(code_lines, lines[i])
      end
      return table.concat(code_lines, '\n'), actual_end
    end
    node = node:parent()
  end

  local end_line = math.min(start_line + 20, #lines)
  local code_lines = {}
  for i = start_line, end_line do
    table.insert(code_lines, lines[i])
  end
  return table.concat(code_lines, '\n'), end_line
end

function M.get_definitions_for_selection(bufnr, start_line, end_line, opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or 2000

  local identifiers = get_identifiers_in_range(bufnr, start_line, end_line)
  local definitions = {}
  local seen_locations = {}

  for _, ident in ipairs(identifiers) do
    local location = lsp_get_definition(bufnr, ident.line, ident.col, timeout_ms)
    if location then
      local info = location_to_info(location)
      if info then
        local key = info.filepath .. ':' .. info.start_line
        if not seen_locations[key] then
          seen_locations[key] = true
          local code, actual_end = read_definition_code(info.filepath, info.start_line)
          if code then
            table.insert(definitions, {
              name = ident.name,
              filepath = info.filepath,
              start_line = info.start_line,
              end_line = actual_end,
              code = code,
            })
          end
        end
      end
    end
  end

  return definitions
end

function M.get_definitions_deep(bufnr, start_line, end_line, opts)
  opts = opts or {}
  local max_depth = opts.max_depth or 3
  local timeout_ms = opts.timeout_ms or 2000
  local max_definitions = opts.max_definitions or 50

  local all_definitions = {}
  local seen_locations = {}
  local queue = {}

  local initial_defs =
    M.get_definitions_for_selection(bufnr, start_line, end_line, { timeout_ms = timeout_ms })
  for _, def in ipairs(initial_defs) do
    local key = def.filepath .. ':' .. def.start_line
    if not seen_locations[key] then
      seen_locations[key] = true
      def.depth = 1
      table.insert(all_definitions, def)
      table.insert(queue, def)
    end
  end

  while #queue > 0 and #all_definitions < max_definitions do
    local current = table.remove(queue, 1)
    if current.depth >= max_depth then goto continue end

    local def_bufnr = vim.fn.bufadd(current.filepath)
    vim.fn.bufload(def_bufnr)

    local nested_defs = M.get_definitions_for_selection(
      def_bufnr,
      current.start_line,
      current.end_line,
      { timeout_ms = timeout_ms }
    )

    for _, def in ipairs(nested_defs) do
      if #all_definitions >= max_definitions then break end
      local key = def.filepath .. ':' .. def.start_line
      if not seen_locations[key] then
        seen_locations[key] = true
        def.depth = current.depth + 1
        table.insert(all_definitions, def)
        table.insert(queue, def)
      end
    end

    ::continue::
  end

  return all_definitions
end

function M.format_definition(def, root)
  local util = require('prompt-yank.util')
  local config = require('prompt-yank.config')
  local lang_mod = require('prompt-yank.lang')
  local format_mod = require('prompt-yank.format')

  local conf = config.get()
  local filepath = util.display_path(def.filepath, root, conf.path_style)
  local language = lang_mod.for_path(def.filepath, conf)

  local tpl = config.resolve_template('definition_item')
  if tpl then
    return format_mod.render_template(tpl, {
      filepath = filepath,
      start_line = def.start_line,
      end_line = def.end_line,
      name = def.name,
      lang = language,
      code = def.code,
    })
  end

  local header = ('`%s#L%d-L%d` (definition: %s)'):format(
    filepath,
    def.start_line,
    def.end_line,
    def.name
  )
  return header .. '\n```' .. language .. '\n' .. def.code .. '\n```'
end

function M.format_definitions(definitions, root)
  local blocks = {}
  for _, def in ipairs(definitions) do
    table.insert(blocks, M.format_definition(def, root))
  end
  return table.concat(blocks, '\n\n')
end

function M.debug_selection(bufnr, start_line, end_line)
  bufnr = bufnr or 0
  local identifiers = get_identifiers_in_range(bufnr, start_line, end_line)
  local clients = get_clients({ bufnr = bufnr })

  local node_types = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if ok and parser then
    local trees = parser:parse()
    if trees and trees[1] then
      local function collect_types(node)
        local sr, _, er, _ = node:range()
        if sr <= end_line - 1 and er >= start_line - 1 then
          local t = node:type()
          node_types[t] = (node_types[t] or 0) + 1
          for child in node:iter_children() do
            collect_types(child)
          end
        end
      end
      collect_types(trees[1]:root())
    end
  end

  local info = {
    buffer = bufnr,
    range = { start_line, end_line },
    lsp_clients = vim.tbl_map(function(c) return c.name end, clients),
    identifiers_found = #identifiers,
    identifiers = identifiers,
    node_types_in_range = node_types,
  }

  vim.print(info)
  return info
end

return M
