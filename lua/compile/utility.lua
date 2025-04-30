local M = {}
local baleia = require("baleia").setup({})

local function edit_under_cursor()
  local filename = vim.fn.expand("<cfile>")
  vim.cmd.wincmd("p")
  vim.cmd.edit(vim.fn.fnameescape(filename))
end

local function filter_output(data)
  local clean = {}
  for _, line in ipairs(data) do
    if line ~= "" then
      line = line:gsub("\r", "")
      line = line:gsub("\x1b%[K", "")
      table.insert(clean, line)
    end
  end
  return clean
end

local function edit_under_cursor_with_col()
  local name = vim.fn.expand("<cfile>")
  if not vim.uv.fs_stat(name) then
    vim.notify([[ERROR: Can't find file "]] .. name .. [[ in path]], vim.log.levels.ERROR)
    return
  end
  local name_len = string.len(name)
  local cursor_col = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()

  local index_start = string.find(line, name)
  while index_start + name_len < cursor_col do
    index_start = string.find(line, name, index_start + 1)
  end
  local linenum = string.match(line, "[%s,%D](%d+)", index_start)
  linenum = tonumber(linenum)
  linenum = math.min(math.max(1, linenum), vim.api.nvim_buf_line_count(0) - 1)
  print(linenum)

  vim.cmd.wincmd("p")
  vim.cmd.edit(vim.fn.fnameescape(name))
  vim.api.nvim_win_set_cursor(0, { linenum, 0 })
  vim.cmd.normal { 'zz', bang = true }
end

M.open_new_or_reuse_window = function(buf, win)
  -- create new buffer if invalid
  local is_buf_valid = buf and vim.api.nvim_buf_is_valid(buf)
  if not is_buf_valid then
    buf = vim.api.nvim_create_buf(true, true)
    baleia.automatically(buf)
    vim.keymap.set({ "n", "n" }, "gf", edit_under_cursor, { buffer = buf })
    vim.keymap.set({ "n", "n" }, "gF", edit_under_cursor_with_col, { buffer = buf })
    if buf == 0 then
      vim.notify("Failed to open new bufdow ", vim.log.levels.ERROR)
      return nil
    end
  end

  --  show window if hidden
  if vim.fn.getbufinfo(buf)[1].hidden == 1 then
    win = vim.api.nvim_open_win(buf, false, { split = "below" })
    if win == 0 then
      vim.notify("Failed to open new window ", vim.log.levels.ERROR)
      win = nil
    end
  end

  return buf, win
end

M.append_to_buffer = function(buf, win)
  return function(_, data)
    if data then
      data = filter_output(data)
      local lastline = vim.api.nvim_buf_line_count(buf) -- colors dosn't work with -1
      vim.api.nvim_buf_set_lines(buf, lastline, -1, false, data)
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_cursor(win, { lastline, 1 })
      end
    end
  end
end

M.on_exit_to_buffer = function(buf)
  return function(_, exit_code, _)
    local lastline = vim.api.nvim_buf_line_count(buf) -- colors dosn't work with -1
    local color = ''
    if exit_code == 0 then
      color = '\x1b[32m'
    else
      color = '\x1b[31m'
    end
    vim.api.nvim_buf_set_lines(buf, lastline, -1, false,
      { color .. 'Finished with exit code: ' .. exit_code .. '\x1b[0m' })
    M._job_id = nil
    vim.notify('Finished with exit code: ' .. exit_code, vim.log.levels.INFO)
  end
end

return M
