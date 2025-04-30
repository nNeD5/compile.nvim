local M = {}

M._buf = nil
M._win = nil
M._cmd = nil
M._job_id = nil

M.setup = function(opts)
  opts = opts or {}
  M.opts = opts

  vim.api.nvim_create_user_command("Compile", M.compile, {})
  vim.api.nvim_create_user_command("CompileSetCmd", M.set_cmd, {})
  vim.api.nvim_create_user_command("CompileStop", M.stop, {})
  M._utility = require("compile.utility")
end

M.compile = function()
  if not M._cmd then
    M.set_cmd()
  end
  if not M._cmd then
    return
  end

  M._buf, M._win = M._utility.open_new_or_reuse_window(M._buf, M._win)

  local lastline = vim.api.nvim_buf_line_count(M._buf)
  vim.api.nvim_buf_set_lines(M._buf, 0, -1, false, {})
  vim.api.nvim_buf_set_lines(M._buf, lastline, -1, false, { '\x1b[32mCompile \27[0m' .. M._cmd .. ':' })
  M.stop()
  M._job_id = vim.fn.jobstart(M._cmd, {
    pty = true,
    on_stdout = M._utility.append_to_buffer(M._buf, M._win),
    on_exit = M._utility.on_exit_to_buffer(M._buf),
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

return M
