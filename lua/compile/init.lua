local M = {}

local compile = require("compile.compile")

function M.setup(opts) end
function M.run_last_cmd()   compile.run_last_cmd() end
function M.stop_cmd()       compile.stop_cmd() end
function M.toggle_cmdwin()  compile.toggle_cmdwin() end
function M.toggle_compwin() compile.toggle_compwin() end

return M
