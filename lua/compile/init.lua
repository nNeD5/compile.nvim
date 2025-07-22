-- TODO: write without space make all text green
-- TODO: add output to cfile

local M = {}

local compile = require("compile.compile")
local window = require("compile.window")
local buffer = require("compile.buffer")
local command_history = require("compile.command_history")
_G.shell_cmd_line_omnicomplete = require("compile.omni_completion")

function M.setup(opts) end

function M.run_cmd() compile.run_cmd() end
function M.stop_cmd() compile.stop_cmd() end
function M.toggle_window() window.toggle_window() end

vim.api.nvim_create_autocmd("FileType", {
  pattern = buffer.get_filetype(),
  callback = function()
    vim.bo.omnifunc = "v:lua.shell_cmd_line_omnicomplete"
  end,
})

return M
