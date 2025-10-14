M = {}

local Path = require("plenary.path")
local data_path = Path:new(vim.fn.stdpath("data"), "compile.nvim")

local function fullpath()
  -- local cwd = Path:new(vim.fn.getcwd())
  -- local h = vim.fn.sha256(cwd.filename)
  local path = Path:new(data_path:joinpath("history" .. ".txt"))
  if not path:exists() then
    path:touch({parents = true})
  end
  return path
end

function M.get_history()
  local path = fullpath()
  local lines = {}

  local data = path:read()
  local i = 1
  for s in data:gmatch("[^\r\n]+") do
    lines[i] = s
    i = i + 1
  end
  return lines
end

function M.save_command(cmd)
  if cmd == nil then return end

  local lines = M.get_history()
  if lines ~= nil and lines[#lines] ~= cmd then
    local path = fullpath()
    path:write(cmd .. '\n', "a")
  end
end

return M
