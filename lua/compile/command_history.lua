M = {}

local Path = require("plenary.path")

local data_path = Path:new(vim.fn.stdpath("data"), "compile.nvim")
local ensured_data_path = false

local function ensure_data_path()
  if ensured_data_path then
    return
  end

  if not data_path:exists() then
    data_path:mkdir()
  end
  ensured_data_path = true
end

local function hash(path)
  return vim.fn.sha256(path)
end

local function fullpath(path)
  local cwd = Path:new(path)
  local h = hash(cwd.filename)
  return Path:new(data_path:joinpath(h .. ".txt"))
end

function get_history(path)
  local lines = {}

  if not path:exists() then
    return lines
  end

  local last_cmd = path:read()
  local i = 0
  for s in last_cmd:gmatch("[^\r\n]+") do
    lines[i] = s
    i = i + 1
  end
  return lines
end

function M.get_last_cmd()
  local path = fullpath(vim.fn.getcwd())
  local history = get_history(path)
  return history[#history]
end

function M.save_command(cmd)
  ensure_data_path()

  if cmd == nil then
    return
  end

  if M.get_last_cmd() == cmd then
    return
  end
  local path = fullpath(vim.fn.getcwd())
  path:write(cmd .. '\n', "a")
end

return M
