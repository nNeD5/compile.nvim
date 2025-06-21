local M = {}

local buf = nil
local baleia = require("baleia").setup({})


local bufname_exists = function(name)
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf_id)
    if vim.fn.fnamemodify(buf_name, ":p") == vim.fn.fnamemodify(name, ":p") then
      return true
    end
  end
  return false
end

local function generate_buf_name()
  local buf_name = "[compile.nvim]"
  local buf_name_duplicate_number = 1
  local new_buf_name = buf_name
  while bufname_exists(new_buf_name) or vim.uv.fs_stat(new_buf_name) ~= nil do
    new_buf_name = buf_name_duplicate_number .. '. ' .. buf_name
    buf_name_duplicate_number = buf_name_duplicate_number + 1
  end
  return new_buf_name
end

local function create_buffer()
  -- create new buffer if invalid
  buf = vim.api.nvim_create_buf(true, true)
  local buf_name = generate_buf_name()
  vim.api.nvim_buf_set_name(buf, buf_name)
  vim.api.nvim_buf_set_lines(buf, 0, 1, true, {"run: "})
  baleia.automatically(buf)
  -- vim.keymap.set({ "n", "n" }, "gf", edit_under_cursor, { buffer = buf })
  -- vim.keymap.set({ "n", "n" }, "gF", edit_under_cursor_with_col, { buffer = buf })
  if buf == 0 then
    vim.notify("Failed to open new bufdow ", vim.log.levels.ERROR)
  end
end


--- Give `compile` buffer, create new if nil
--- @return (integer | nil)
function M.get_buffer()
  local is_buf_valid = buf and vim.api.nvim_buf_is_valid(buf)
  if not is_buf_valid then
    create_buffer()
  end
  return buf
end

return M
