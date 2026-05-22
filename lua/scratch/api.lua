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

local function get_scratch_files(scratch_dir)
  local entries = utils.list_scratch_files(scratch_dir)
  local res = {}
  for _, entry in ipairs(entries) do
    res[#res + 1] = entry.path:sub(#scratch_dir + 2)
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
    return
  end

  if vim.fn.executable("rg") ~= 1 then
    utils.log_err("Can't find rg executable, please check your configuration")
    return
  end
  local cfg = vim.g.scratch_config
  fzf_lua.files({ cmd = "rg --files --sortr modified " .. vim.fn.shellescape(cfg.scratch_file_dir) })
end

local function open_scratch_telescope()
  local ok, telescope_builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify(
      'ScratchOpen needs telescope.nvim or you can set file_picker to "fzflua", "snacks", or nil to use native select ui'
    )
    return
  end

  local config_data = vim.g.scratch_config
  local keys = config_data.picker_keys or {}
  local delete_key = keys.delete or "<C-x>"

  telescope_builtin.find_files({
    cwd = config_data.scratch_file_dir,
    attach_mappings = function(prompt_bufnr, map)
      map("n", delete_key, function()
        require("scratch.telescope_actions").delete_item(prompt_bufnr)
      end)
      return true
    end,
  })
end

--- Open a snacks picker for scratch files.
---@param initial_mode "files"|"grep"|"multi"
---@param current_mode? "files"|"grep"|"multi"
local function open_scratch_snacks(initial_mode, current_mode)
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    utils.log_err("Can't find snacks.nvim, please check your configuration")
    return
  end

  local cfg = vim.g.scratch_config
  local keys = cfg.picker_keys or {}
  local cwd = cfg.scratch_file_dir
  local mode = current_mode or initial_mode

  local titles =
    { files = "Scratch [files]", grep = "Scratch [content]", multi = "Scratch [multi]" }

  local function picker_config_for_mode(m)
    if m == "multi" then
      return {
        finder = function(opts, ctx)
          local files_mod = require("snacks.picker.source.files")
          local grep_mod = require("snacks.picker.source.grep")

          return function(cb)
            -- Files: uses filter.search as glob for fd (empty = all files)
            local files_result = files_mod.files(opts, ctx:clone())
            if type(files_result) == "function" then
              files_result(cb)
            elseif type(files_result) == "table" then
              for _, item in ipairs(files_result) do
                cb(item)
              end
            end

            -- Grep: uses filter.search as regex for rg (skip if empty)
            if (ctx.filter.search or "") ~= "" then
              local grep_result = grep_mod.grep(opts, ctx:clone())
              if type(grep_result) == "function" then
                grep_result(cb)
              elseif type(grep_result) == "table" then
                for _, item in ipairs(grep_result) do
                  cb(item)
                end
              end
            end
          end
        end,
        live = true,
        supports_live = true,
        matcher = { sort_empty = true, frecency = true },
      }
    elseif m == "grep" then
      return { finder = "grep", live = true, supports_live = true }
    else
      return {
        finder = "files",
        live = false,
        supports_live = false,
        matcher = { sort_empty = true },
      }
    end
  end

  local mode_cfg = picker_config_for_mode(mode)

  local picker_opts = vim.tbl_extend("force", {
    source = "scratch",
    title = titles[mode],
    cwd = cwd,
    format = "file",
    preview = "file",
    show_empty = true,
    sort = { fields = { "score:desc", "mtime:desc", "idx" } },
    transform = function(item)
      local path = item.cwd and (item.cwd .. slash .. item.file) or item.file
      if path then
        item.mtime = utils.get_file_mtime(path)
      end
    end,
    confirm = function(picker, item, action)
      require("snacks.picker.actions").jump(picker, item, action)
      if item and item.pos then
        vim.fn.setreg("/", picker.input.filter.search or "")
      end
    end,
    actions = {
      toggle_mode = function(picker)
        if initial_mode == "multi" then
          if mode == "multi" then
            mode = "files"
          elseif mode == "files" then
            mode = "grep"
          else
            mode = "multi"
          end
        else
          mode = mode == "grep" and "files" or "grep"
        end
        picker:close()
        vim.schedule(function()
          open_scratch_snacks(initial_mode, mode)
        end)
      end,
      delete_file = function(picker, item)
        if not item or not item.file then
          utils.log_err("No file selected to delete")
          return
        end
        local name = vim.fn.fnamemodify(item.file, ":t")
        if vim.fn.confirm("Delete " .. name .. "?", "&Yes\n&No", 2) == 1 then
          local abs = item.cwd and (item.cwd .. slash .. item.file) or item.file
          utils.remove_file_and_empty_parents(abs, cwd)
          picker:find({ refresh = true })
        end
      end,
    },
    win = {
      input = {
        keys = {
          [keys.delete or "<C-x>"] = { "delete_file", mode = { "n" }, desc = "Delete scratch file" },
          [keys.toggle_mode or "<C-f>"] = {
            "toggle_mode",
            mode = { "i", "n" },
            desc = "Toggle content/file search",
          },
        },
      },
    },
  }, mode_cfg)

  snacks.picker(picker_opts)
end

local function open_scratch_vim_ui()
  local cfg = vim.g.scratch_config
  local scratch_file_dir = cfg.scratch_file_dir
  local files = get_scratch_files(scratch_file_dir)

  -- Pre-compute modification times for O(n) instead of O(n log n) getftime calls
  local mtimes = {}
  for _, f in ipairs(files) do
    mtimes[f] = vim.fn.getftime(scratch_file_dir .. slash .. f)
  end

  table.sort(files, function(a, b)
    return mtimes[a] > mtimes[b]
  end)

  vim.ui.select(files, {
    prompt = "Select old scratch files",
    format_item = function(item)
      return item
    end,
  }, function(chosenFile)
    if chosenFile then
      create_and_edit_file(scratch_file_dir .. slash .. chosenFile, { config_data = cfg })
      register_local_key(cfg)
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
    open_scratch_snacks(config_data.picker_snacks_multi and "multi" or "files")
  else
    open_scratch_vim_ui()
  end
end

local function fzfScratch()
  local config_data = vim.g.scratch_config
  local scratch_dir = config_data.scratch_file_dir

  if config_data.file_picker == "snacks" then
    open_scratch_snacks("grep")
  elseif config_data.file_picker == "fzflua" then
    local ok, fzf_lua = pcall(require, "fzf-lua")
    if not ok then
      utils.log_err("Can't find fzf-lua, please check your configuration")
      return
    end
    if vim.fn.executable("rg") ~= 1 then
      utils.log_err("Can't find rg executable, please check your configuration")
      return
    end
    fzf_lua.live_grep({ cwd = scratch_dir })
  elseif config_data.file_picker == "telescope" then
    local ok, telescope_builtin = pcall(require, "telescope.builtin")
    if not ok then
      utils.log_err("ScratchOpenFzf needs telescope.nvim")
      return
    end
    telescope_builtin.live_grep({ cwd = scratch_dir })
  else
    open_scratch_vim_ui()
  end
end

return {
  createScratchFileByName = createScratchFileByName,
  createScratchFileByType = createScratchFileByType,
  scratch = scratch,
  scratchWithName = scratch_with_name,
  openScratch = openScratch,
  fzfScratch = fzfScratch,
}
