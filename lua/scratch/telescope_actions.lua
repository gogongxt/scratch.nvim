local M = {}

local utils = require("scratch.utils")

function M.delete_item(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local picker = action_state.get_current_picker(prompt_bufnr)
  picker:delete_selection(function(s)
    local file_name = s[1]
    local scratch_file_dir = vim.g.scratch_config.scratch_file_dir
    local full_path = scratch_file_dir .. utils.Slash() .. file_name
    if vim.fn.filereadable(full_path) == 1 then
      utils.remove_file_and_empty_parents(full_path, scratch_file_dir)
      return true
    end
    return false
  end)
end

return M
