local M =  {}


-- TODO: remove plenary
local Path = require("plenary.path")
local data_path = Path:new(vim.fn.stdpath("data"), "compile.nvim")

local compbufid  = nil
local compwin_id = nil
local cmdbuf_id  = nil
local cmdwin_id  = nil
local jobid = nil

-- ==================
-- HISTORY
-- ==================
local function fullpath()
  -- local cwd = Path:new(vim.fn.getcwd())
  -- local h = vim.fn.sha256(cwd.filename)
  local path = Path:new(data_path:joinpath("history" .. ".txt"))
  if not path:exists() then
    path:touch({parents = true})
  end
  return path
end

local function get_history()
  local path = fullpath()
  local lines = {}

  local data = path:read()
  local i = 1
  -- only non empty lines
  for s in data:gmatch("[^\r\n]+") do
    lines[i] = s
    i = i + 1
  end
  return lines
end

local function save_command(cmd)
  if cmd == nil then return end

  local lines = get_history()
  if lines ~= nil and lines[#lines] ~= cmd then
    local path = fullpath()
    path:write(cmd .. '\n', "a")
  end
end

local function get_last_cmd()
  -- TODO: something strange, should be just get_history().last
  -- get cmd from input buffer
  local lines = {}
  if cmdbuf_id == nil or not vim.api.nvim_buf_is_loaded(cmdbuf_id) then
    lines = get_history()
  else
    lines = vim.api.nvim_buf_get_lines(cmdbuf_id, 0, -1, false)
  end
  local cmd = lines[#lines]
  if cmd == nil then
    vim.notify("Command isn't set", vim.log.levels.WARN)
    return nil
  end
  cmd = cmd:match("^%s*(.-)%s*$") -- trim trailing whitepsaces
  if cmd == nil or cmd == "" then
    vim.notify("Can't parse command", vim.log.levels.WARN)
    return nil
  end
  return cmd
end

-- ==================
-- CMD WINDOW
-- ==================
local function setup_cmdbuf()
  vim.api.nvim_set_option_value("buftype", "nofile", {scope="local", buf=cmdbuf_id})
  vim.keymap.set({"n", "v", "i"}, "<CR>", function()
      local cmd = vim.api.nvim_get_current_line()
      save_command(cmd)
      vim.api.nvim_buf_delete(cmdbuf_id, {})
      M.run_cmd(cmd)
    end,
    {buffer=cmdbuf_id})
end

local function open_cmdwin()
  -- create cmd buffer
  if cmdbuf_id == nil or not vim.api.nvim_buf_is_valid(cmdbuf_id) then
    cmdbuf_id = vim.api.nvim_create_buf(false, true)
    setup_cmdbuf()
  end

  local lines = get_history()
  vim.api.nvim_buf_set_lines(cmdbuf_id, 0, -1, false, lines)
  cmdwin_id = vim.api.nvim_open_win(cmdbuf_id, true, {
    split="below",
    win = -1,
    height = vim.o.cmdwinheight,
  })
  vim.api.nvim_win_set_cursor(cmdwin_id,  {#lines, 0})
end

function M.toggle_cmdwin()
  local wins_with_buf = vim.fn.win_findbuf(cmdbuf_id)
  if vim.tbl_isempty(wins_with_buf) then
    open_cmdwin()
    return
  end

  for _, win in pairs(wins_with_buf) do
    vim.api.nvim_win_close(win, false)
  end
end

-- ==================
-- COMPILATION WINDOW
-- ==================
local function setup_compbuf()
  vim.api.nvim_set_option_value("modified", false, {scope="local", buf=comp_bufid})
end
-- Open a window and display the compilation window.
-- If there is a compilation window open already, use
-- that one. Otherwise, if the current window uses the
-- full width of the screen or is at least 80 characters
-- wide, the compilation window will appear just above the
-- current window. Otherwise the new window is put at
-- the very top.
local function open_comp_window(focus)
  -- create terminal buffer
  if compbuf_id == nil or not vim.api.nvim_buf_is_valid(compbuf_id) then
    compbuf_id = vim.api.nvim_create_buf(false, true)
    setup_compbuf()
  end

  if compwin_id ~= nil and vim.api.nvim_win_is_valid(compwin_id) then
    vim.api.nvim_win_set_buf(compwin_id, compbuf_id)
    if focus then vim.api.nvim_set_current_win(compwin_id) end
    return
  end

  local wins_with_buf = vim.fn.win_findbuf(compbuf_id)
  if vim.tbl_isempty(wins_with_buf) then
    -- TODO: calculate layout
    compwin_id = vim.api.nvim_open_win(compbuf_id, false, { split="right", win = -1, })
  else
    compwin_id = wins_with_buf[0]
  end
    vim.api.nvim_win_set_buf(compwin_id, compbuf_id)
  if focus then vim.api.nvim_set_current_win(compwin_id) end
end

function M.toggle_compwin()
  if compwin_id ~= nil and vim.api.nvim_win_is_valid(compwin_id) then
    vim.api.nvim_win_close(compwin_id, false)
  else
    open_comp_window(true)
  end

end


-- ==================
-- RUN
-- ==================

function M.run_last_cmd()
  M.run_cmd(get_last_cmd())
end

function M.run_cmd(cmd)
  -- TODO: A way to run more then one command simultaneously
  if jobid ~= nil then
    vim.notify("Kill previous job" .. cmd, vim.log.levels.WARN)
    vim.fn.jobstop(jobid)
    vim.fn.jobwait({jobid})
  end

  vim.notify("Compile: " .. cmd, vim.log.levels.INFO)
  local save_current_win = vim.api.nvim_get_current_win()
  open_comp_window(true)
  vim.api.nvim_set_option_value("modified", false, {buf=compbuf_id})
  jobid = vim.fn.jobstart("time " .. cmd, {
    pty = true,
    term = true,
    on_stdout = function()
      if vim.api.nvim_win_is_valid(compwin_id) then
        local last = vim.api.nvim_buf_line_count(compbuf_id)
        vim.api.nvim_win_set_cursor(compwin_id, { last, 0 })
      end
    end,
    on_stderr = function()
      if vim.api.nvim_win_is_valid(compwin_id) then
        local last = vim.api.nvim_buf_line_count(term_bufid)
        vim.api.nvim_win_set_cursor(compwin_id, { last, 0 })
      end
    end,
    on_exit = function()
      jobid = nil
      vim.cmd.cgetbuffer(compbuf_id)
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
vim.keymap.set("n", "<leader>i",  M.toggle_cmdwin)
vim.keymap.set("n", "<leader>o",  M.toggle_compwin)
-- vim.keymap.set("n", "<leader>r",  M.toggle_compwin)
return M
