local M = {}
local compile = require("compile.compile")
local window = require("compile.window")

function M.setup(opts) end

function M.run_cmd() compile.run_cmd() end
function M.stop_cmd() compile.stop_cmd() end
function M.toggle_window() window.toggle_window() end


return M
