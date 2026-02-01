local function Slash()
  local slash = "/"
  if vim.fn.has("win32") == 1 then
    slash = "\\"
  end
  return slash
end

local slash = Slash()
local uv = vim.uv or vim.loop

--- generate abs filepath
---@param filename string
---@param parentDir string
---@param requiresDir boolean
---@return string
local function genFilepath(filename, parentDir, requiresDir)
  if requiresDir then
    local dirName = os.date("%y%m%d%H%M%S") .. "-" .. string.format("%04x", math.random(0, 0xFFFF))
    vim.fn.mkdir(parentDir .. slash .. dirName, "p")
    return parentDir .. slash .. dirName .. slash .. filename
  else
    return parentDir .. slash .. filename
  end
end

---@param localKeys Scratch.LocalKey[]
local function setLocalKeybindings(localKeys)
  for _, localKey in ipairs(localKeys) do
    vim.keymap.set(localKey.modes, localKey.key, localKey.cmd, {
      noremap = true,
      silent = true,
      nowait = true,
      buffer = vim.api.nvim_get_current_buf(),
    })
  end
end

---@param substr string
---@return boolean
local function filenameContains(substr)
  local s = vim.fn.expand("%:t")
  if string.find(s, substr) then
    return true
  else
    return false
  end
end

---@return string[]
local function getSelectedText(mark, selection_mode)
  local pos1 = vim.fn.getpos("v")
  local pos2 = vim.fn.getpos(mark)
  local lines = {}
  local start_row, start_col, end_row, end_col = pos1[2], pos1[3], pos2[2], pos2[3]
  local text = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, true)
  end_row = end_row - start_row + 1
  start_row = 1
  if selection_mode == "v" then
    table.insert(lines, text[1]:sub(start_col))
    for i = start_row + 1, end_row do
      table.insert(lines, text[i])
    end
    lines[end_row] = lines[end_row]:sub(1, end_col)
  elseif selection_mode == "V" then
    for i = start_row, end_row do
      table.insert(lines, text[i])
    end
  elseif selection_mode == vim.api.nvim_replace_termcodes("<C-V>", true, true, true) then
    for i = start_row, end_row do
      table.insert(lines, text[i]:sub(start_col, end_col))
    end
  end
  return lines
end

---@param msg string
local function log_err(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "scratch.nvim" })
end

---@param title string
---@return {buf: integer, win: integer}
local function new_popup_window(title)
  local popup_buf = vim.api.nvim_create_buf(false, false)

  local opts = {
    relative = "editor", -- Assuming you want the floating window relative to the editor
    row = 2,
    col = 5,
    width = vim.o.columns - 10,
    height = vim.o.lines - 5,
    style = "minimal",
    border = "single",
    title = title,
  }

  local win = vim.api.nvim_open_win(popup_buf, true, opts)
  return {
    buf = popup_buf,
    win = win,
  }
end

--- Recursively list files with sortable timestamp keys
---@param dir string
---@return {path: string, sort_key: string}[]
local function list_scratch_files(dir)
  local files = {}
  local handle = uv.fs_scandir(dir)
  if not handle then
    return files
  end
  while true do
    local name, typ = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local full = dir .. slash .. name
    if typ == "directory" then
      local sub = list_scratch_files(full)
      for _, f in ipairs(sub) do
        files[#files + 1] = f
      end
    else
      local ts = name:match("^(%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d)")
      if not ts then
        local stat = uv.fs_stat(full)
        ts = stat and os.date("%y-%m-%d_%H-%M-%S", stat.mtime.sec) or "00-00-00_00-00-00"
      end
      files[#files + 1] = { path = full, sort_key = ts }
    end
  end
  return files
end

--- Remove a file and clean up empty parent directories up to (not including) stop_dir
---@param filepath string
---@param stop_dir string
local function remove_file_and_empty_parents(filepath, stop_dir)
  local ok, err = os.remove(filepath)
  if not ok then
    vim.notify(
      "scratch.nvim: failed to delete " .. filepath .. ": " .. tostring(err),
      vim.log.levels.WARN
    )
    return
  end
  local dir = vim.fn.fnamemodify(filepath, ":h")
  while dir ~= stop_dir and dir ~= "/" do
    local entries = vim.fn.readdir(dir)
    if entries and #entries == 0 then
      vim.fn.delete(dir, "d")
      dir = vim.fn.fnamemodify(dir, ":h")
    else
      break
    end
  end
end

return {
  Slash = Slash,
  genFilepath = genFilepath,
  setLocalKeybindings = setLocalKeybindings,
  filenameContains = filenameContains,
  getSelectedText = getSelectedText,
  log_err = log_err,
  new_popup_window = new_popup_window,
  list_scratch_files = list_scratch_files,
  remove_file_and_empty_parents = remove_file_and_empty_parents,
}
