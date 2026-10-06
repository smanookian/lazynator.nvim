-- Nudges: when you do something the slow way, show the key for it.
-- Slow ways: a typed ":" command that has a keymap, a mouse click on a buffer tab or the file tree.
local M = {}

local config = require("lazynator.config")
local groups = require("lazynator.groups")
local keys = require("lazynator.keys")
local progress = require("lazynator.progress")
local track = require("lazynator.track")
local ui = require("lazynator.ui")

local uv = vim.uv or vim.loop
local shown = {} ---@type table<string, integer> last time a hint was shown, ms
local hint = {} ---@type lazynator.Float
local hint_timer
local listeners = {} ---@type fun(id:string, why:string)[]

---@return fun() unsubscribe
function M.on_nudge(fn)
  listeners[#listeners + 1] = fn
  return function()
    for i, f in ipairs(listeners) do
      if f == fn then
        table.remove(listeners, i)
        return
      end
    end
  end
end

local function skipped(id)
  for _, lhs in ipairs(config.options.nudge.skip or {}) do
    if keys.id(lhs) == id then
      return true
    end
  end
  return false
end

local function show_hint(id, desc, why)
  local function draw()
    ui.show(hint, {
      pos = "bottom",
      redraw = draw,
      lines = ui.with_spacey("think", {
        vim.list_extend({ { "Next time: " } }, ui.caps(id)),
        { { desc } },
        { { why, "LazynatorDim" } },
      }),
    })
  end
  draw()
  hint_timer = hint_timer or uv.new_timer()
  hint_timer:stop()
  hint_timer:start(config.options.nudge.timeout, 0, vim.schedule_wrap(function()
    ui.close(hint)
  end))
end

--- You did something the slow way; `id` is the key for it.
---@param id string
---@param why string short text, e.g. "You typed :bd"
---@param live? table<string, lazynator.Key>
function M.nudge(id, why, live)
  local o = config.options.nudge
  if not o.enabled or skipped(id) then
    return
  end
  live = live or keys.live()
  local k = live[id]
  if not k then
    return
  end
  track.ensure(id)
  progress.nudge(id)
  for _, fn in ipairs(listeners) do
    pcall(fn, id, why)
  end
  local now = uv.now()
  if shown[id] and now - shown[id] < o.every * 60 * 1000 then
    return
  end
  shown[id] = now
  vim.schedule(function()
    show_hint(id, k.desc, why)
  end)
end

--- Nudge for the first key of a list that exists in your config.
function M.nudge_first(list, why)
  local live = keys.live()
  local id = keys.first(list, live)
  if id then
    M.nudge(id, why, live)
  end
end

-- Typed commands ---------------------------------------------------------------

---@return {cmd:string, args:string[], bang:boolean}?
function M.parse(line)
  line = vim.trim(line)
  local ok, p = pcall(vim.api.nvim_parse_cmd, line, {})
  if ok then
    if (p.range and #p.range > 0) or (p.nextcmd and p.nextcmd ~= "") then
      return nil
    end
    return { cmd = p.cmd, args = p.args or {}, bang = p.bang == true }
  end
  -- Not a command here (for example :Telescope when Telescope is not installed).
  local name, bang, rest = line:match("^(%a[%w_]*)(!?)%s*(.-)$")
  if not name or rest:find("|", 1, true) then
    return nil
  end
  return { cmd = name, args = vim.split(rest, "%s+", { trimempty = true }), bang = bang == "!" }
end

local function args_match(want, args)
  local s = table.concat(args, " ")
  if want == nil then
    return s == ""
  elseif want == "*" then
    return true
  elseif want == "+" then
    return s ~= "" and s ~= "#" and s ~= "%" and s ~= "."
  end
  return s == want
end

local set_cmds = { set = true, setlocal = true, setglobal = true }

local function set_match(names, args)
  for _, a in ipairs(args) do
    if a:sub(-1) ~= "?" then
      local name = a:match("^([%a]+)")
      if name then
        name = name:gsub("^inv", "")
        for _, n in ipairs(names) do
          if name == n or name == "no" .. n then
            return true
          end
        end
      end
    end
  end
  return false
end

--- The command a text keymap runs, e.g. "<Cmd>tabnew<CR>" -> "tabnew". Nil if it does more than that.
function M.rhs_command(rhs)
  if type(rhs) ~= "string" then
    return nil
  end
  local s = rhs:gsub("^<[Cc][Mm][Dd]>", ""):gsub("^:", "")
  local body, tail = s:match("^(.-)<[Cc][Rr]>(.*)$")
  if not body or not (tail == "" or tail:lower() == "<esc>") then
    return nil
  end
  if body == "" or body:find("[<|]") then
    return nil
  end
  return body
end

local function same(a, b)
  return a.cmd == b.cmd and a.bang == b.bang and table.concat(a.args, " ") == table.concat(b.args, " ")
end

--- The key for a typed command line, or nil.
---@param line string
---@param live? table<string, lazynator.Key>
function M.match(line, live)
  local p = M.parse(line)
  if not p or groups.quit[p.cmd] then
    return nil
  end
  live = live or keys.live()
  for _, s in ipairs(groups.slow) do
    local hit
    if s.set then
      hit = set_cmds[p.cmd] and set_match(s.set, p.args)
    else
      hit = s.cmd == p.cmd and args_match(s.args, p.args)
    end
    if hit then
      local id = keys.first(s.key, live)
      if id then
        return id
      end
    end
  end
  -- Text keymaps whose right-hand side is the same command.
  -- Prefer keys from the lesson list (earlier first), then shorter keys.
  local pos = keys.index().pos
  local function better(a, b)
    if not b then
      return true
    end
    local pa, pb = pos[a] or math.huge, pos[b] or math.huge
    if pa ~= pb then
      return pa < pb
    end
    if #a ~= #b then
      return #a < #b
    end
    return a < b
  end
  local best
  for id, k in pairs(live) do
    local c = M.rhs_command(k.rhs)
    local q = c and M.parse(c)
    if q and same(p, q) and better(id, best) then
      best = id
    end
  end
  return best
end

function M.on_cmdline()
  if vim.fn.getcmdtype() ~= ":" or vim.v.event.abort or not track.cmd_typed then
    return
  end
  local line = vim.fn.getcmdline()
  local live = keys.live()
  local id = M.match(line, live)
  if id then
    M.nudge(id, "You typed :" .. vim.trim(line), live)
  end
end

-- Mouse ------------------------------------------------------------------------

local function is_tree(win)
  if not (win and win ~= 0 and vim.api.nvim_win_is_valid(win)) then
    return false
  end
  local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
  if ft == "neo-tree" then
    return true
  end
  if ft:find("^snacks_picker") and package.loaded.snacks then
    local ok, pickers = pcall(function()
      return require("snacks").picker.get({ source = "explorer" })
    end)
    for _, p in ipairs(ok and pickers or {}) do
      for _, part in ipairs({ p.list, p.input }) do
        if part and part.win and part.win.win == win then
          return true
        end
      end
    end
  end
  return false
end

local into_timer
local into = false

--- Mouse keys you typed. A click into the tree from another window -> tree key.
--- A double click that opens a file -> find files key.
function M.on_mouse(t)
  if t ~= "<LeftMouse>" and t ~= "<2-LeftMouse>" then
    return
  end
  if not config.options.nudge.mouse then
    return
  end
  local pos = vim.fn.getmousepos()
  if not is_tree(pos.winid) then
    return
  end
  into_timer = into_timer or uv.new_timer()
  if t == "<LeftMouse>" then
    into = pos.winid ~= vim.api.nvim_get_current_win()
    if into then
      into_timer:stop()
      into_timer:start(vim.o.mousetime + 50, 0, vim.schedule_wrap(function()
        if into then
          into = false
          M.nudge_first(groups.mouse.tree, "You clicked the file tree")
        end
      end))
    end
  else
    into_timer:stop()
    local was_into = into
    into = false
    vim.defer_fn(function()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "" and not is_tree(win) then
        M.nudge_first(groups.mouse.tree_open, "You opened a file with the mouse")
      elseif was_into then
        M.nudge_first(groups.mouse.tree, "You clicked the file tree")
      end
    end, 120)
  end
end

--- A click on a bufferline tab (kind "handle_click") or its close icon ("handle_close").
function M.on_tab(kind, id, button)
  if not config.options.nudge.mouse then
    return
  end
  if kind == "handle_close" or button == "r" then
    return M.nudge_first(groups.mouse.tab_close, "You closed a tab with the mouse")
  end
  if kind ~= "handle_click" or button ~= "l" then
    return
  end
  local cur = vim.api.nvim_get_current_buf()
  if id == cur then
    return
  end
  local which = "tab_other"
  local ok, res = pcall(function()
    return require("bufferline").get_elements().elements
  end)
  if ok and type(res) == "table" then
    local ci, ti
    for i, e in ipairs(res) do
      if e.id == cur then
        ci = i
      elseif e.id == id then
        ti = i
      end
    end
    if ci and ti then
      which = ti == ci + 1 and "tab_next" or ti == ci - 1 and "tab_prev" or which
    end
  end
  M.nudge_first(groups.mouse[which], "You clicked a tab")
end

local hooked = setmetatable({}, { __mode = "k" })

--- Hook bufferline's click handlers (it calls them by name from the tabline).
function M.hook_bufferline()
  local p = rawget(_G, "___bufferline_private")
  if type(p) ~= "table" then
    return
  end
  for _, name in ipairs({ "handle_click", "handle_close" }) do
    local orig = p[name]
    if type(orig) == "function" and not hooked[orig] then
      local function wrapped(id, clicks, button, mods)
        pcall(M.on_tab, name, id, button)
        return orig(id, clicks, button, mods)
      end
      hooked[wrapped] = true
      p[name] = wrapped
    end
  end
end

function M.start()
  local group = vim.api.nvim_create_augroup("lazynator.nudge", { clear = true })
  vim.api.nvim_create_autocmd("CmdlineLeave", { group = group, callback = M.on_cmdline })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "LazyLoad",
    callback = function()
      vim.schedule(M.hook_bufferline)
    end,
  })
  M.hook_bufferline()
  track.on_key(M.on_mouse)
end

return M
