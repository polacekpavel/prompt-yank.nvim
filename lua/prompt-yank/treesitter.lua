local M = {}

local container_types = {
  function_declaration = true,
  function_definition = true,
  function_item = true,
  ["function"] = true,
  method_definition = true,
  method_declaration = true,
  class_declaration = true,
  class_definition = true,
  struct_item = true,
  enum_item = true,
  impl_item = true,
  trait_item = true,
  if_statement = true,
  for_statement = true,
  while_statement = true,
  switch_statement = true,
  try_statement = true,
}

local name_types = {
  identifier = true,
  type_identifier = true,
  field_identifier = true,
  property_identifier = true,
  name = true,
}

local function node_text(node, bufnr)
  local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
  if not ok then
    return nil
  end
  return text
end

local function find_name(node, bufnr)
  local field = node:field("name")
  if field and field[1] then
    return node_text(field[1], bufnr)
  end

  for child in node:iter_children() do
    if child:named() and name_types[child:type()] then
      return node_text(child, bufnr)
    end
  end

  return nil
end

local function inclusive_end_line(sr, er, ec)
  if ec == 0 and er > sr then
    return er
  end
  return er + 1
end

function M.current_container(bufnr)
  bufnr = bufnr or 0

  if not vim.treesitter or not vim.treesitter.get_parser then
    return nil, "Tree-sitter not available"
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil, "No Tree-sitter parser for buffer"
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]

  local trees = parser:parse()
  if not trees or not trees[1] then
    return nil, "Failed to parse Tree-sitter tree"
  end

  local root = trees[1]:root()
  local node = root:named_descendant_for_range(row, col, row, col)

  while node do
    if container_types[node:type()] then
      local sr, _, er, ec = node:range()
      local start_line = sr + 1
      local end_line = inclusive_end_line(sr, er, ec)
      local name = find_name(node, bufnr)
      return {
        start_line = start_line,
        end_line = end_line,
        name = name,
        node_type = node:type(),
      }
    end
    node = node:parent()
  end

  return nil, "No enclosing function/class/block found"
end

return M
