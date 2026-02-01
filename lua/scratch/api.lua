local config = require("scratch.config")
local utils = require("scratch.utils")
local slash = utils.Slash()
local Hooks = require("scratch.hooks")
local MANUAL_INPUT_OPTION = "MANUAL_INPUT"

---@class Scratch.ActionOpts
---@field window_cmd? Scratch.WindowCmd
---@field content? string[] content will be put into the scratch file
---@field config_data? Scratch.Config
---@field ft? string

---@param abs_path string
---@param opts? Scratch.ActionOpts
local function create_and_edit_file(abs_path, opts)
  -- Create parent directory if it doesn't exist
  local parent_dir = vim.fn.fnamemodify(abs_path, ":h")
  if vim.fn.isdirectory(parent_dir) == 0 then
    vim.fn.mkdir(parent_dir, "p")
  end

  local config_data = opts and opts.config_data or vim.g.scratch_config
  local cmd = (opts and opts.window_cmd) or config_data.window_cmd or "edit"
  if cmd == "popup" then
    utils.new_popup_window(abs_path)
    vim.cmd("w " .. vim.fn.fnameescape(abs_path))
  else
    vim.api.nvim_command(cmd .. " " .. vim.fn.fnameescape(abs_path))
  end

  local hooks = Hooks.get_hooks(config_data.hooks, Hooks.trigger_points.AFTER)
  for _, hook in ipairs(hooks) do
    local ok, err = pcall(
      hook.callback,
      { abs_path = abs_path, ft = opts and opts.ft, bufnr = vim.api.nvim_get_current_buf() }
    )
    if not ok then
      utils.log_err(
        "Hook" .. (hook.name and (" '" .. hook.name .. "'") or "") .. " failed: " .. tostring(err)
      )
    end
  end
end

local function write_lines_to_buffer(lines)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

---@param filename string
local function createScratchFileByName(filename)
  local cfg = vim.g.scratch_config
  local scratch_file_dir = cfg.scratch_file_dir

  local fullpath = scratch_file_dir .. slash .. filename
  create_and_edit_file(fullpath, { config_data = cfg })
end

---@param config_data Scratch.Config
local function register_local_key(config_data)
  local localKeys = config_data.localKeys
  if localKeys and #localKeys > 0 then
    for _, key in ipairs(localKeys) do
      for _, namePattern in ipairs(key.filenameContains) do
        if utils.filenameContains(namePattern) then
          utils.setLocalKeybindings(key.LocalKeys)
        end
      end
    end
  end
end

---@param ft string
---@param opts? Scratch.ActionOpts
local function write_default_content(ft, opts)
  if opts and opts.content then
    write_lines_to_buffer(opts.content)
  else
    local config_data = opts and opts.config_data or vim.g.scratch_config

    local has_default_content = config_data.filetype_details[ft]
      and config_data.filetype_details[ft].content
      and #config_data.filetype_details[ft].content > 0

    if has_default_content then
      write_lines_to_buffer(config_data.filetype_details[ft].content)
    end
  end
end

---@param ft string
---@param config_data Scratch.Config
local function put_cursor(ft, config_data)
  local has_cursor_position = config_data.filetype_details[ft]
    and config_data.filetype_details[ft].cursor
    and #config_data.filetype_details[ft].cursor.location > 0

  if has_cursor_position then
    vim.api.nvim_win_set_cursor(0, config_data.filetype_details[ft].cursor.location)
    if config_data.filetype_details[ft].cursor.insert_mode then
      vim.api.nvim_feedkeys("a", "n", true)
    end
  end
end

---@param ft string
---@param opts? Scratch.ActionOpts
local function createScratchFileByType(ft, opts)
  local cfg = vim.g.scratch_config
  local merged = vim.tbl_extend("force", opts or {}, { config_data = cfg, ft = ft })

  local abs_path = config.get_abs_path(ft, cfg)

  create_and_edit_file(abs_path, merged)
  write_default_content(ft, merged)
  put_cursor(ft, cfg)
  register_local_key(cfg)
end

---@param config_data Scratch.Config
---@return string[]
local function get_all_filetypes(config_data)
  local seen = {}
  local combined_filetypes = {}
  for _, ft in ipairs(config_data.filetypes or {}) do
    if not seen[ft] then
      seen[ft] = true
      combined_filetypes[#combined_filetypes + 1] = ft
    end
  end
  for ft, _ in pairs(config_data.filetype_details or {}) do
    if not seen[ft] then
      seen[ft] = true
      combined_filetypes[#combined_filetypes + 1] = ft
    end
  end
  combined_filetypes[#combined_filetypes + 1] = MANUAL_INPUT_OPTION
  return combined_filetypes
end

---@param func Scratch.Action
---@param opts? Scratch.ActionOpts
local function select_filetype_then_do(func, opts)
  local cfg = vim.g.scratch_config
  local filetypes = get_all_filetypes(cfg)

  vim.ui.select(filetypes, {
    prompt = "Select filetype",
    format_item = function(item)
      return item
    end,
  }, function(chosen_ft)
    if chosen_ft then
      if chosen_ft == MANUAL_INPUT_OPTION then
        vim.ui.input({ prompt = "Input filetype: " }, function(ft)
          func(ft, opts)
        end)
      else
        func(chosen_ft, opts)
      end
    end
  end)
end

local function get_scratch_files()
  local config_data = vim.g.scratch_config
  local scratch_file_dir = config_data.scratch_file_dir
  local res = {}
  res = utils.listDirectoryRecursive(scratch_file_dir)
  for i, str in ipairs(res) do
    res[i] = string.sub(str, string.len(scratch_file_dir) + 2)
  end
  return res
end

---@param opts? Scratch.ActionOpts
local function scratch(opts)
  select_filetype_then_do(createScratchFileByType, opts)
end

local function scratch_with_name()
  vim.ui.input({
    prompt = "Enter the file name: ",
  }, function(filename)
    if filename ~= nil and filename ~= "" then
      createScratchFileByName(filename)
    end
  end)
end

local function open_scratch_fzflua()
  local ok, fzf_lua = pcall(require, "fzf-lua")
  if not ok then
    utils.log_err("Can't find fzf-lua, please check your configuration")
  end

  if vim.fn.executable("rg") ~= 1 then
    utils.log_err("Can't find rg executable, please check your configuration")
  end
  fzf_lua.files({ cmd = "rg --files --sortr modified " .. vim.g.scratch_config.scratch_file_dir })
end

local function open_scratch_telescope()
  local config_data = vim.g.scratch_config

  if not telescope_status then
    vim.notify(
      'ScrachOpen needs telescope.nvim or you can just add `"use_telescope: false"` into your config file ot use native select ui'
    )
    return
  end

  telescope_builtin.find_files({
    cwd = config_data.scratch_file_dir,
    attach_mappings = function(prompt_bufnr, map)
      -- TODO: user can customise keybinding
      map("n", "dd", function()
        require("scratch.telescope_actions").delete_item(prompt_bufnr)
      end)

      return true
    end,
  })
end

local function open_scratch_snacks()
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    utils.log_err("Can't find snacks.nvim, please check your configuration")
    return
  end

  -- Check if rg is available
  if vim.fn.executable("rg") ~= 1 then
    utils.log_err("Can't find rg executable, please check your configuration")
    -- Fallback to default snacks behavior
    snacks.picker.files({
      cwd = vim.g.scratch_config.scratch_file_dir,
      prompt = "Scratch Files",
    })
    return
  end

  -- Use rg with sorting by modified time
  snacks.picker.files({
    cmd = "rg",
    args = { "--files", "--sortr", "modified" },
    cwd = vim.g.scratch_config.scratch_file_dir,
    prompt = "Scratch Files",
  })
end

local function open_scratch_vim_ui()
  local files = get_scratch_files()
  local config_data = vim.g.scratch_config

  local scratch_file_dir = config_data.scratch_file_dir

  -- sort the files by their last modified time in descending order
  table.sort(files, function(a, b)
    return vim.fn.getftime(scratch_file_dir .. slash .. a)
      > vim.fn.getftime(scratch_file_dir .. slash .. b)
  end)

  vim.ui.select(files, {
    prompt = "Select old scratch files",
    format_item = function(item)
      return item
    end,
  }, function(chosenFile)
    if chosenFile then
      create_and_edit_file(scratch_file_dir .. slash .. chosenFile)
      register_local_key()
    end
  end)
end

local function openScratch()
  local config_data = vim.g.scratch_config

  if config_data.file_picker == "telescope" then
    open_scratch_telescope()
  elseif config_data.file_picker == "fzflua" then
    open_scratch_fzflua()
  elseif config_data.file_picker == "snacks" then
    open_scratch_snacks()
  else
    open_scratch_vim_ui()
  end
end

local function fzfScratch()
  local config_data = vim.g.scratch_config
  if not telescope_status then
    vim.notify("ScrachOpenFzf needs telescope.nvim")
    return
  end

  telescope_builtin.live_grep({
    cwd = config_data.scratch_file_dir,
  })
end

return {
  createScratchFileByName = createScratchFileByName,
  createScratchFileByType = createScratchFileByType,
  scratch = scratch,
  scratchWithName = scratch_with_name,
  openScratch = openScratch,
  fzfScratch = fzfScratch,
}
