local M = {}

local subs = {
  lesson = function(args)
    require("lazynator.lesson").start(args[2])
  end,
  stats = function()
    require("lazynator.menu").stats()
  end,
  skip = function()
    require("lazynator.lesson").skip()
  end,
  stop = function()
    require("lazynator.lesson").stop()
  end,
}

---@param args string[]
function M.run(args)
  if #args == 0 then
    return require("lazynator.menu").open()
  end
  local f = subs[args[1]]
  if not f then
    vim.notify("Lazynator: unknown command '" .. args[1] .. "'. Try: lesson, stats, skip, stop")
    return
  end
  f(args)
end

local function starting_with(list, lead)
  return vim.tbl_filter(function(s)
    return s:sub(1, #lead) == lead
  end, list)
end

function M.complete(lead, line)
  local words = vim.split(line:sub(1, -#lead - 1), "%s+", { trimempty = true })
  if #words == 1 then
    return starting_with(vim.tbl_keys(subs), lead)
  end
  if #words == 2 and words[2] == "lesson" then
    return starting_with(
      vim.tbl_map(function(g)
        return g.id
      end, require("lazynator.groups").list),
      lead
    )
  end
  return {}
end

return M
