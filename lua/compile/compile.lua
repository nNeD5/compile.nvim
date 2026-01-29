local M =  {}

local compbufid  = nil
local compwin_id = nil
local cmdbuf_id  = nil
local cmdwin_id  = nil
local jobid = nil

-- ==================
-- HISTORY
-- ==================
function fullpath()
  local data_path = vim.fn.stdpath("data")
  local path = data_path .. "/compile.nvim/history.txt"

  if vim.fn.filereadable(path) == 0 then
    vim.notify("Failed to read file: " .. path, vim.log.levels.ERROR)
    return nil
  end
  return path
end

local function get_history()
  local path = fullpath()
  local data = vim.fn.readfile(path)

  -- only non empty lines
  local lines = {}
  local i = 1
  for _, s in pairs(data) do
    s = s:match("^%s*(.-)%s*$") -- trim trailing whitepsaces
    if #s ~= 0 then lines[i] = s end
    i = i + 1
  end
  return lines
end

-- TODO: remove same command, before saving
local function save_command(cmd)
  if cmd == nil then return end

  local lines = get_history()
  if lines == nil or lines[#lines] == cmd then
    return
  end

  local path = fullpath()
  vim.fn.writefile({cmd .. '\n'}, path, "a")
end

local function get_last_cmd()
  lines = get_history()
  cmd = lines[#lines]
  if cmd == nil then
    vim.notify("Command isn't set", vim.log.levels.WARN)
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
  end
  setup_cmdbuf()

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
  local function window_with_filename(filename)
    local target = vim.fn.fnamemodify(filename, ":p") -- absolute path

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fn.fnamemodify(name, ":p") == target then
        return win
      end
    end
    return nil
  end

  local function edit_under_cursor()
    local filename = vim.fn.expand("<cfile>")
    local win = window_with_filename(filename)
    if win ~= nil then
      vim.api.nvim_set_current_win(win)
    else
      vim.cmd.wincmd("p")
    end
    vim.cmd.edit(vim.fn.fnameescape(filename))
  end

  local function edit_under_cursor_with_col()
    local name = vim.fn.expand("<cfile>")
    if not vim.uv.fs_stat(name) then
      vim.notify([[Can't find file "]] .. name .. [[" in path]], vim.log.levels.ERROR)
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

    if win ~= nil then
      nvim.api.nvim_set_current_win(win)
    else
      vim.cmd.wincmd("p")
    end
    vim.cmd.edit(vim.fn.fnameescape(name))
    vim.api.nvim_win_set_cursor(0, { linenum, 0 })
    vim.cmd.normal { 'zz', bang = true }
  end

  vim.api.nvim_set_option_value("modified", false, {buf=compbuf_id})
  vim.keymap.set({"n", "t"}, "gf", function() edit_under_cursor() end, {buffer=compbuf_id})
  vim.keymap.set({"n", "t"}, "gF", function() edit_under_cursor_with_col() end, {buffer=compbuf_id})
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
  end
  setup_compbuf()

  if compwin_id ~= nil and vim.api.nvim_win_is_valid(compwin_id) then
    vim.api.nvim_win_set_buf(compwin_id, compbuf_id)
    if focus then vim.api.nvim_set_current_win(compwin_id) end
    return
  end

  local wins_with_buf = vim.fn.win_findbuf(compbuf_id)
  if vim.tbl_isempty(wins_with_buf) then
     config = {}
    if vim.api.nvim_win_get_width(0) > 80 then
      config = {split="above", win=0,}
    else
      config = {split="above", win=-1,}
    end
    compwin_id = vim.api.nvim_open_win(compbuf_id, false, config)
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
return M
