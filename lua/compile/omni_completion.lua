-- Negative return values:
--    -2	To cancel silently and stay in completion mode.
--    -3	To cancel silently and leave completion mode.
--    Another negative value: completion starts at the cursor column
local function shell_cmd_line_omnicomplete(findstart, base)
  if findstart == 1 then
    local _, line, _, _ = table.unpack(vim.fn.getpos('.'))
    local line_content = vim.fn.getline('.')
    local _, prefix_end = line_content:find("^%s*run:%s*")

    -- handle incorret
    if line ~= 1 then
      return -3
    elseif prefix_end == nil then
      return -3
    end

    return prefix_end
  end

  if findstart == 0 then
    local matches = vim.fn.getcompletion(base, "shellcmdline")
    if matches ~= nil and string.sub(base, -1) == " " then
      for i = 1, #matches do
        matches[i] = base .. matches[i]
      end
    end
    return matches
  end
end

return shell_cmd_line_omnicomplete
