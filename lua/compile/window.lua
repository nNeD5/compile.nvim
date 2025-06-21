local M = {}
local buffer = require("compile.buffer")

function M.open_window()
  --  show window if hidden
  local buf = buffer.get_buffer()
  if vim.fn.getbufinfo(buf)[1].hidden == 1 then
    -- local curr_win_height = vim.api.nvim_win_get_height(0)
    -- local height_factor = opts.height or 0.5
    -- local height = math.floor(curr_win_height * height_factor)
    local win = vim.api.nvim_open_win(buf, false, { split = "below"})
    if win == 0 then
      vim.notify("Failed to open new window ", vim.log.levels.ERROR)
    end
  end
end

function M.toggle_window()
  --  show window if hidden
  local buf = buffer.get_buffer()
  local buf_info = vim.fn.getbufinfo(buf)[1]
  if buf_info.hidden == 1 then
    vim.api.nvim_open_win(buf, false, {split ='below'})
  else
    for _, win in ipairs(buf_info.windows) do
      vim.api.nvim_win_close(win, false)
    end
  end
end


return M

