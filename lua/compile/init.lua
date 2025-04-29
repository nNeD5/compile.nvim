local M = {}

M._buf = nil
M._cmd = nil
M._job_id = nil

M.setup = function(opts)
  opts = opts or {}
  M.opts = opts

  vim.api.nvim_create_user_command("Compile", M.compile, {})
  vim.api.nvim_create_user_command("CompileSetCmd", M.set_cmd, {})
  vim.api.nvim_create_user_command("CompileStop", M.stop, {})
  M._baleia = require("baleia").setup({})
end

M.compile = function()
  if not M._cmd then
    M.set_cmd()
  end
  if not M._cmd then
    return
  end

  M._open_new_or_reuse_window()

  M._baleia.buf_set_lines(M._buf, 0, -1, false, { '\x1b[32mCompile \x1b[0m' .. M._cmd .. ':' })
  M._job_id = vim.fn.jobstart(M._cmd, {
    pty = true,
    on_stdout = M._append_to_buffer,
    on_exit = M._on_exit_to_buffer,
  })
end

M.set_cmd = function()
  vim.ui.input({ prompt = "Compile cmd: ", completion = "shellcmd" },
    function(input)
      M._cmd = input
    end)
end

M.stop = function()
  if M._job_id == nil then
    vim.notify("None job is runnig (job id is nil)", vim.log.levels.INFO)
    return
  end

  vim.fn.jobstop(M._job_id)
end

M._on_exit_to_buffer = function(_, exit_code, _)
  local lastline = vim.api.nvim_buf_line_count(M._buf) -- colors dosn't work with -1
  local color = ''
  if exit_code == 0 then
    color = '\x1b[32m'
  else
    color = '\x1b[31m'
  end
  M._baleia.buf_set_lines(M._buf, lastline, -1, false,
    { color .. 'Finished with exit code: ' .. exit_code .. '\x1b[0m' })
  M._job_id = nil
end

M._append_to_buffer = function(_, data)
  if data then
    data = M._filter_output(data)
    local lastline = vim.api.nvim_buf_line_count(M._buf) -- colors dosn't work with -1
    M._baleia.buf_set_lines(M._buf, lastline, -1, false, data)
  end
end

M._open_new_or_reuse_window = function()
  -- create new buffer if invalid
  local is_buf_valid = M._buf and vim.api.nvim_buf_is_valid(M._buf)
  if not is_buf_valid then
    M._buf = vim.api.nvim_create_buf(true, true)
    if M._buf == 0 then
      vim.notify("Failed to open new bufdow ", vim.log.levels.ERROR)
    end
  end

  --  show window if hidden
  if vim.fn.getbufinfo(M._buf)[1].hidden == 1 then
    local output_win = vim.api.nvim_open_win(M._buf, false, { split = "below" })
    if output_win == 0 then
      vim.notify("Failed to open new window ", vim.log.levels.ERROR)
    end
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
