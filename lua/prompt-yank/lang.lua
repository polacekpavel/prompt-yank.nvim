local M = {}

function M.for_filetype(filetype, conf)
  if not filetype or filetype == '' then return '' end
  local map = (conf and conf.lang_map) or {}
  return map[filetype] or filetype
end

function M.for_extension(extension, conf)
  if not extension or extension == '' then return '' end
  local map = (conf and conf.ext_map) or {}
  return map[extension] or extension
end

function M.for_buffer(bufnr, conf)
  local ft = vim.bo[bufnr or 0].filetype
  return M.for_filetype(ft, conf)
end

function M.for_path(path, conf)
  local ext = vim.fn.fnamemodify(path or '', ':e')
  ext = (ext or ''):lower()
  return M.for_extension(ext, conf)
end

return M
