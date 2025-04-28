local M = {}

M._output_buf = nil
M._output_win = nil
M._cmd = nil

M.setup = function(opts)
  opts = opts or {}
  M.opts = opts

  vim.api.nvim_create_user_command("Compile", M.compile, {})
  vim.api.nvim_create_user_command("CompileSetCmd", M.set_cmd, {})
  M._baleia = require('baleia').setup({})
end

M.compile = function()
  if not M._cmd then
    M.set_cmd()
  end
  if M._cmd == nil then
    return
  end

  M._open_new_or_reuse_window()

  M._baleia.buf_set_lines(M._output_buf, 0, -1, false, { '\x1b[32mCompile \x1b[0m' .. M._cmd .. ':' })
  vim.fn.jobstart(M._cmd, {
    pty = true,
    on_stdout = M._append_to_buffer,
    on_exit = M._on_exit_to_buffer,
  })
end

M.set_cmd = function()
  M._cmd = vim.fn.input("Compile cmd: ")
end

M._on_exit_to_buffer = function(_, exit_code, _)
  local lastline = vim.api.nvim_buf_line_count(M._output_buf) -- colors dosn't work with -1
  if exit_code == 0 then
    color = '\x1b[32m'
  else
    color = '\x1b[31m'
  end
  M._baleia.buf_set_lines(M._output_buf, lastline, -1, false,
    { color .. 'Finished with exit code: ' .. exit_code .. '\x1b[0m' })
end

M._append_to_buffer = function(_, data)
  if data then
    data = M._filter_output(data)
    local lastline = vim.api.nvim_buf_line_count(M._output_buf) -- colors dosn't work with -1
    M._baleia.buf_set_lines(M._output_buf, lastline, -1, false, data)
  end
end

M._open_new_or_reuse_window = function()
  if M._output_buf and vim.api.nvim_buf_is_valid(M._output_buf) then return end
  if M._output_win and vim.api.nvim_win_is_valid(M._output_win) then return end

  M._output_buf = vim.api.nvim_create_buf(true, true)
  if M._output_buf == 0 then
    vim.notify("Failed to open new bufdow ", vim.log.levels.ERROR)
    return
  end

  M._output_win = vim.api.nvim_open_win(M._output_buf, false, { split = "below" })
  if M._output_win == 0 then
    vim.notify("Failed to open new window ", vim.log.levels.ERROR)
    return
  end
end

M._filter_output = function(data)
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

return M
