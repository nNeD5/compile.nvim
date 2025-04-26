local M = {} -- M stands for module, a naming convention

function M.setup(opts)
  opts = opts or {}

  M.opts = opts

  print("compile.nvim loaded with opts:")
  print(vim.inspect(M.opts))
end


-- local buf = 21
--
-- local function filter_output(data)
--   local clean = {}
--   for _, line in ipairs(data) do
--     if line ~= "" then
--       line = line:gsub("\r", "")
--       line = line:gsub("", "")
--       table.insert(clean, line)
--     end
--   end
--   return clean
-- end
--
-- vim.fn.jobstart("python test.py", {
--   pty = 1,
--   on_stdout = function(_, data)
--     if data then
--       data = filter_output(data)
--       print(vim.inspect(data))
--       vim.api.nvim_buf_set_lines(buf, -1, -1, false, data)
--     end
--   end
-- })
