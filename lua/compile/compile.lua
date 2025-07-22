local M = {}

-- TODO: fix. This odin code can't output to buffer
-- package main
-- import "core:fmt"
-- import "core:strconv"
-- main :: proc() {
--     buf: [4]byte
--     result := strconv.write_int(buf[:], -42, 10)
--     fmt.println(result, buf)
--     for b in buf {
--         fmt.printfln("%c", b)
--     }
-- }
--

local buffer = require("compile.buffer")
local window = require("compile.window")
local command_history = require("compile.command_history")
local job_id = nil;
local cmd = nil

--- Parse first line in format 'run: <cmd>' from buf and return cmd
--- @return string
local function cmd_from_buf()
  local lines = vim.api.nvim_buf_get_lines(buffer.get_buffer(), 0, 1, false)
  local cmd = lines[1]
  if cmd == nil then return nil end
  local cmd = cmd:match(":(.*)")
  if cmd == nil then return nil end
  local cmd = cmd:match("^%s*(.-)%s*$") -- trim trailing whitepsaces
  if cmd == nil then return nil end

  return cmd
end


--- clean part of string not parsed by baleia
--- @param data
local function clean_sting(data)
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

local function append_to_buffer()
  return function(_, data)
    if data then
      data = clean_sting(data)
      local lastline = vim.api.nvim_buf_line_count(buffer.get_buffer()) -- colors dosn't work with -1
      vim.api.nvim_buf_set_lines(buffer.get_buffer(), lastline, -1, false, data)
      -- vim.api.nvim_win_set_cursor(win, { lastline, 1 })
    end
  end
end

local function on_exit_to_buffer()
  return function(_, exit_code, _)
    local lastline = vim.api.nvim_buf_line_count(buffer.get_buffer()) -- colors dosn't work with -1
    local color = ''
    if exit_code == 0 then
      color = '\x1b[32m'
    else
      color = '\x1b[31m'
    end
    vim.api.nvim_buf_set_lines(buffer.get_buffer(), lastline, -1, false,
      { color .. 'Finished with exit code: ' .. exit_code .. '\x1b[0m' })
    M._job_id = nil
    vim.notify('Finished with exit code: ' .. exit_code, vim.log.levels.INFO)
    -- if vim.api.nvim_win_is_valid(win) then
    --   vim.api.nvim_win_set_cursor(win, { lastline, 1 })
    -- end
  end
end

--- run command from first line in buffer
function M.run_cmd()
  -- order important, first crate_buf then get cmd
  local buf = buffer.get_buffer()
  cmd = cmd_from_buf()
  window.open_window()
  if cmd == nil then
    vim.notify("Command isn't set", vim.log.levels.WARN)
    return
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, { '\x1b[32mrun: \x1b[0m' .. cmd })
  command_history.save_command(cmd)
  job_id = vim.fn.jobstart(cmd, {
    pty = true,
    on_stdout = append_to_buffer(M._buf, M._win),
    on_exit = on_exit_to_buffer(M._buf, M._win),
  })
end

function M.stop_cmd()
  if job_id == nil then
    vim.notify("No commands is running", vim.log.levels.WARN)
    return
  end
  vim.fn.jobstop(job_id)
end

function M.get_cmd()
  return cmd
end


return M
