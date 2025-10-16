local M =  {}

local term_bufid = nil
local input_bufid = nil
local term_winid = nil
local input_winid = nil
local jobid = nil
local history = require("compile.command_history")
local group = vim.api.nvim_create_augroup("compile.linked_windows", { clear = true })

local function get_last_cmd_from_input_buffer()
  -- get cmd from input buffer
  local lines = {}
  if input_bufid == nil or not vim.api.nvim_buf_is_loaded(input_bufid) then
    lines = history.get_history()
  else
    lines = vim.api.nvim_buf_get_lines(input_bufid, 0, -1, false)
  end
  local cmd = lines[#lines]
  if cmd == nil then
    vim.notify("Command isn't set", vim.log.levels.WARN)
    return nil
  end
  local cmd = cmd:match("^%s*(.-)%s*$") -- trim trailing whitepsaces
  if cmd == nil or cmd == "" then
    vim.notify("Can't parse command", vim.log.levels.WARN)
    return nil
  end
  return cmd
end

local function open_window(focus)
  focus = focus or false
  -- close term win -> closes input win as well
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if tonumber(args.match) == term_winid then
        if vim.api.nvim_win_is_valid(input_winid) then
          vim.api.nvim_win_close(input_winid, false)
        end
      end
    end,
  })

  -- create terminal buffer
  if term_bufid == nil or not vim.api.nvim_buf_is_loaded(term_bufid) then
    term_bufid = vim.api.nvim_create_buf(true, true)
  end
  -- create input buffer
  if input_bufid == nil or not vim.api.nvim_buf_is_loaded(input_bufid) then
    input_bufid = vim.api.nvim_create_buf(true, true)
    local lines = history.get_history()
    vim.api.nvim_buf_set_lines(input_bufid, 0, -1, false, lines)
  end
  -- open windows
  local save_current_win = vim.api.nvim_get_current_win()
  if term_winid == nil or vim.fn.getbufinfo(term_bufid)[1].hidden == 1 then
    term_winid = vim.api.nvim_open_win(term_bufid, false, { split = "right", win = 0 })
    input_winid = vim.api.nvim_open_win(input_bufid, true, {win=term_winid, height=vim.o.cmdwinheight, split="below"})
    vim.keymap.set({"n", "v", "i"}, "<CR>", function() M.run_cmd(vim.api.nvim_get_current_line()) end, { buffer = true })
    if focus == false then
      vim.api.nvim_set_current_win(save_current_win)
    end
  end

  vim.api.nvim_set_option_value("modified", false, {scope="local", buf=term_bufid})
end


function M.run_last_cmd()
  M.run_cmd(get_last_cmd_from_input_buffer())
end

function M.run_cmd(cmd)
  if jobid ~= nil then
    vim.notify("Kill previous job" .. cmd, vim.log.levels.WARN)
    vim.fn.jobstop(jobid)
    vim.fn.jobwait({jobid})
  end

  open_window()
  history.save_command(cmd)
  vim.api.nvim_buf_set_lines(input_bufid, 0, -1, false, history.get_history())
  vim.api.nvim_win_set_cursor(input_winid,  {#vim.api.nvim_buf_get_lines(input_bufid, 0, -1, false), 0})
  vim.notify("Compile: " .. cmd, vim.log.levels.INFO)
  local save_current_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(term_winid)
  jobid = vim.fn.jobstart("time " .. cmd, {
    pty = true,
    term = true,
    on_stdout = function()
      if vim.api.nvim_win_is_valid(term_winid) then
        local last = vim.api.nvim_buf_line_count(term_bufid)
        vim.api.nvim_win_set_cursor(term_winid, { last, 0 })
      end
    end,
    on_stderr = function()
      if vim.api.nvim_win_is_valid(term_winid) then
        local last = vim.api.nvim_buf_line_count(term_bufid)
        vim.api.nvim_win_set_cursor(term_winid, { last, 0 })
      end
    end,
    on_exit = function()
      jobid = nil
      vim.cmd.cgetbuffer(term_bufid)
    end,
  })
  vim.api.nvim_set_current_win(save_current_win)
end

function M.stop_cmd()
  if jobid == nil then
    vim.notify("None is running", vim.log.levels.INFO)
    return
  end
  vim.fn.jobstop(jobid)
    vim.notify("Job killed", vim.log.levels.WARN)
end

function M.toggle_window()
  local is_hidden = term_bufid == nil
  local is_hidden = is_hidden or not vim.api.nvim_buf_is_loaded(term_bufid)
  local is_hidden = is_hidden or vim.fn.getbufinfo(term_bufid)[1].hidden == 1
  if is_hidden then
    open_window(true)
  else
    for _, win in ipairs(vim.fn.getbufinfo(term_bufid)[1].windows) do
      vim.api.nvim_win_close(win, false)
    end
  end
end


return M
