-- TODO: If compile window in new tab it messed path path and swith to this tab
-- TODO: update README and push to main
local M =  {}

local compbufid  = nil
local compwin_id = nil
local cmdbuf_id  = nil
local cmdwin_id  = nil
local jobid = nil

-- ==================
-- HISTORY
-- ==================
local function fullpath()
  local data_path = vim.fn.stdpath("data")
  local path = data_path .. "/compile.nvim/history.txt"

  if vim.fn.filereadable(path) == 0 then
    vim.notify("File " .. path .. "is not readable" , vim.log.levels.ERROR)
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
  local lines = get_history()
  local cmd = lines[#lines]
  if cmd == nil then
    vim.notify("Failed to get last command", vim.log.levels.WARN)
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

-- TODO: Bug: compwin_id not nil / valid, when it shouldn't
--       value is the same as in other file
local function open_cmdwin()
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

  local all_wins = vim.api.nvim_tabpage_list_wins(0)
  if #all_wins == 1 then
    vim.notify("Can't close last window", vim.log.levels.WARN)
  else
    for _, win in pairs(wins_with_buf) do
      vim.api.nvim_win_close(win, false)
    end
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

  local function edit_under_cursor_with_pos()
    local filename = vim.fn.expand("<cfile>")
    if not vim.uv.fs_stat(filename) then
      vim.notify([[Can't find file "]] .. filename .. [[" in path]], vim.log.levels.ERROR)
      return
    end
    local line = vim.api.nvim_get_current_line()
    local _, file_end_col = string.find(line, filename, 0, true)
    linenum = string.match(line, "[%s,%D](%d+)", file_end_col)
    linenum = tonumber(linenum)
    local win = window_with_filename(filename)
    if win ~= nil then
      vim.api.nvim_set_current_win(win)
    else
      vim.cmd.wincmd("p")
    end
    vim.cmd.edit(vim.fn.fnameescape(filename))
    if linenum ~= nil and linenum > 0 and linenum < vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, { linenum, 0 })
      vim.cmd.normal { 'zz', bang = true }
    else
      if lienum ~= nil then
        vim.notify("Line " .. linenum .. " outside the buffer", vim.log.levels.WARN)
      end
    end
  end

  vim.api.nvim_set_option_value("modified", false, {buf=compbuf_id})
  vim.keymap.set({"n", "t"}, "gf", function() edit_under_cursor_with_pos() end, {buffer=compbuf_id})
  vim.keymap.set({"n", "t"}, "gF", function() edit_under_cursor_with_pos() end, {buffer=compbuf_id})
end

-- Open a window and display the compilation window.
-- If there is a compilation window open already, use
-- that one. Otherwise, if the current window uses the
-- full width of the screen or is at least 80 characters
-- wide, the compilation window will appear just above the
-- current window. Otherwise the new window is put at
-- the very top.
local function open_compwin(focus)
  -- create terminal buffer
  if compbuf_id == nil or not vim.api.nvim_buf_is_valid(compbuf_id) then
    compbuf_id = vim.api.nvim_create_buf(false, true)
  end
  setup_compbuf()

  if compwin_id ~= nil and vim.api.nvim_win_is_valid(compwin_id) and vim.api.nvim_win_get_buf(compwin_id) == compbuf_id then
    if focus then vim.api.nvim_set_current_win(compwin_id) end
    return
  end

  if vim.api.nvim_win_get_width(0) > 80 then
    config = {split="above", win=0,}
  else
    config = {split="above", win=-1,}
  end
  compwin_id = vim.api.nvim_open_win(compbuf_id, false, config)

  vim.api.nvim_win_set_buf(compwin_id, compbuf_id)
  if focus then vim.api.nvim_set_current_win(compwin_id) end
end

-- TODO: do something else when only this window
-- Warning?
function M.toggle_compwin()
  if compwin_id ~= nil and vim.api.nvim_win_is_valid(compwin_id) == true and vim.api.nvim_win_get_buf(compwin_id) == compbuf_id  then
  local all_wins = vim.api.nvim_tabpage_list_wins(0)
    if #all_wins > 1 then
      vim.api.nvim_win_close(compwin_id, false)
    else
      vim.notify("Can't close last window", vim.log.levels.WARN)
    end
  else
    open_compwin(true)
  end

end


-- ==================
-- RUN
-- ==================
function M.run_last_cmd(jump)
  M.run_cmd(get_last_cmd(), jump)
end

function M.run_cmd(cmd, jump)
  -- TODO: A way to run more then one command simultaneously
  if jobid ~= nil then
    vim.notify("Kill previous job" .. cmd, vim.log.levels.WARN)
    vim.fn.jobstop(jobid)
    vim.fn.jobwait({jobid})
  end

  vim.notify("Compile: " .. cmd, vim.log.levels.INFO)
  local save_current_win = vim.api.nvim_get_current_win()
  open_compwin(true)
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
      if jump == true then
        if vim.api.nvim_win_is_valid(compwin_id) == false  then
          open_cmdwin()
        end
        vim.api.nvim_win_set_cursor(compwin_id, {1, 0})
      end
      vim.cmd.cgetbuffer(compbuf_id)
    end,
  })
  if jump == false then
    vim.api.nvim_set_current_win(save_current_win)
  end
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
