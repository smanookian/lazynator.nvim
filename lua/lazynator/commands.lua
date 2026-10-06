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
  reset = function(args)
    M.reset(args[2])
  end,
}

--- Reset progress for everything, or for one group. Asks first.
---@param group_id? string
function M.reset(group_id)
  local groups = require("lazynator.groups")
  local progress = require("lazynator.progress")
  local group = group_id and groups.get(group_id)
  if group_id and not group then
    vim.notify("Lazynator: no group called '" .. group_id .. "'. Try: " .. table.concat(
      vim.tbl_map(function(g)
        return g.id
      end, groups.list),
      ", "
    ))
    return
  end
  local what = group and (group.name .. " progress") or "all Lazynator progress"
  if vim.fn.confirm("Reset " .. what .. "?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  if group then
    local keys = require("lazynator.keys")
    local ids = {}
    for id in pairs(progress.all()) do
      if keys.group_of(id) == group.id then
        ids[#ids + 1] = id
      end
    end
    progress.reset(ids)
  else
    progress.reset()
  end
  vim.notify("Lazynator: " .. what .. " is reset.")
end

---@param args string[]
function M.run(args)
  if #args == 0 then
    return require("lazynator.menu").open()
  end
  local f = subs[args[1]]
  if not f then
    vim.notify("Lazynator: unknown command '" .. args[1] .. "'. Try: lesson, stats, skip, stop, reset")
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
  if #words == 2 and (words[2] == "lesson" or words[2] == "reset") then
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
