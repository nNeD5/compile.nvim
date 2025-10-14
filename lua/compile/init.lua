local M = {}

local compile = require("compile.compile")

function M.setup(opts) end
function M.run_cmd() compile.run_last_cmd() end
function M.stop_cmd() compile.stop_cmd() end
function M.toggle_window() compile.toggle_window() end

return M
