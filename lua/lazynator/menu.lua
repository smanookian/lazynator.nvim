-- :Lazynator (pick a lesson) and :Lazynator stats.
local M = {}

local config = require("lazynator.config")
local groups = require("lazynator.groups")
local keys = require("lazynator.keys")
local progress = require("lazynator.progress")
local ui = require("lazynator.ui")

local win = {} ---@type lazynator.Float

local function pad(s, n)
  return s .. string.rep(" ", math.max(0, n - vim.api.nvim_strwidth(s)))
end

local function lpad(s, n)
  return string.rep(" ", math.max(0, n - vim.api.nvim_strwidth(s))) .. s
end

--- learned / learning / new counts per group, from your live keymaps.
---@return {id:string, name:string, learned:integer, learning:integer, new:integer, total:integer}[]
function M.counts()
  local live = keys.live()
  local out = {}
  local in_group = {}
  for _, g in ipairs(groups.list) do
    local c = { id = g.id, name = g.name, learned = 0, learning = 0, new = 0, total = 0 }
    for _, k in ipairs(keys.group_keys(g, live)) do
      in_group[k.id] = true
      local s = progress.state(k.id)
      c[s] = c[s] + 1
      c.total = c.total + 1
    end
    out[#out + 1] = c
  end
  local other = { id = "other", name = "Other", learned = 0, learning = 0, new = 0, total = 0 }
  for id in pairs(progress.all()) do
    if live[id] and not in_group[id] then
      local s = progress.state(id)
      other[s] = other[s] + 1
      other.total = other.total + 1
    end
  end
  if other.total > 0 then
    out[#out + 1] = other
  end
  return out
end

local function close()
  ui.close(win)
end

local function map(lhs, fn)
  vim.keymap.set("n", lhs, fn, { buffer = win.buf, nowait = true, silent = true })
end

local function after_show()
  -- Close when you leave the window, but only that window: the menu may already have been
  -- replaced by the stats (or the other way round) in the same slot.
  local mine = win.win
  vim.api.nvim_create_autocmd("WinLeave", {
    group = vim.api.nvim_create_augroup("lazynator.menu", { clear = true }),
    buffer = win.buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if win.win == mine then
          close()
        end
      end)
    end,
  })
  map("q", close)
  map("<Esc>", close)
end

--- The lesson menu.
---@param opts? {select?: integer} lesson to put the cursor on (after a lesson: the next one)
function M.open(opts)
  opts = opts or {}
  local counts = M.counts()
  local nxt = opts.select and groups.list[opts.select]
  local lines = ui.with_spacey(nxt and "happy" or "idle", {
    { { nxt and "Well done!" or "Hi! I'm Spacey.", "LazynatorTitle" } },
    { { nxt and ("Next: " .. nxt.name .. ". Press Enter.") or "Pick a lesson: press its number." } },
    { { nxt and "Or press another number, or q to stop." or "Only real key presses count.", "LazynatorDim" } },
  })
  lines[#lines + 1] = {}
  local first_row = #lines + 1
  for i, g in ipairs(groups.list) do
    local c = counts[i]
    lines[#lines + 1] = {
      { (" %d  "):format(i), "LazynatorAccent" },
      { pad(g.name, 10) },
      { ui.size() == "small" and "" or ui.bar(c.learned, c.total, 10, c.learning) .. "  ", "LazynatorLearned" },
      { ("%d/%d learned"):format(c.learned, c.total), "LazynatorDim" },
      { c.learning > 0 and ("  · %d learning"):format(c.learning) or "", "LazynatorLearning" },
    }
  end
  lines[#lines + 1] = {}
  lines[#lines + 1] = {
    { " s", "LazynatorAccent" },
    { " stats    " },
    { "q", "LazynatorAccent" },
    { " close" },
  }
  local function redraw()
    M.open(opts)
  end
  local top = ui.show(win, { pos = "center", lines = lines, title = "Lazynator", focus = true, width = 44, redraw = redraw })
  first_row = first_row + top
  vim.api.nvim_win_set_cursor(win.win, { first_row + (opts.select or 1) - 1, 0 })
  for i, g in ipairs(groups.list) do
    map(tostring(i), function()
      close()
      require("lazynator.lesson").start(g.id)
    end)
  end
  map("<CR>", function()
    local i = vim.api.nvim_win_get_cursor(0)[1] - first_row + 1
    local g = groups.list[i]
    if g then
      close()
      require("lazynator.lesson").start(g.id)
    end
  end)
  map("s", function()
    close()
    M.stats()
  end)
  after_show()
end

--- learned / learning / new, per group.
function M.stats()
  local counts = M.counts()
  local lines = ui.with_spacey("happy", {
    { { "Your progress", "LazynatorTitle" } },
    { { ("Learned = pressed %d times in a row,"):format(config.options.learned_after) } },
    { { "with no nudge in between.", "LazynatorDim" } },
  })
  lines[#lines + 1] = {}
  lines[#lines + 1] = {
    { pad("Group", 10) },
    { lpad("Learned", 9), "LazynatorLearned" },
    { lpad("Learning", 10), "LazynatorLearning" },
    { lpad("New", 6), "LazynatorNew" },
  }
  local tl, tg, tn = 0, 0, 0
  for _, c in ipairs(counts) do
    tl, tg, tn = tl + c.learned, tg + c.learning, tn + c.new
    lines[#lines + 1] = {
      { pad(c.name, 10) },
      { lpad(tostring(c.learned), 9) },
      { lpad(tostring(c.learning), 10) },
      { lpad(c.id == "other" and "-" or tostring(c.new), 6) },
    }
  end
  lines[#lines + 1] = {
    { pad("Total", 10), "LazynatorDim" },
    { lpad(tostring(tl), 9), "LazynatorDim" },
    { lpad(tostring(tg), 10), "LazynatorDim" },
    { lpad(tostring(tn), 6), "LazynatorDim" },
  }
  lines[#lines + 1] = {}
  lines[#lines + 1] = { { "q", "LazynatorAccent" }, { " close" } }
  ui.show(win, { pos = "center", lines = lines, title = "Lazynator stats", focus = true, redraw = M.stats })
  after_show()
end

return M
