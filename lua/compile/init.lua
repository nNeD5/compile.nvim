local M = {}

function M.setup(opts)
  opts = opts or {}

  M.opts = opts

  print("compile.nvim loaded with opts:")
  print(vim.inspect(M.opts))
end
return M
