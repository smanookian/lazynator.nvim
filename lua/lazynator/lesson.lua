-- Lessons: show 3-5 keys of a group, then you press each one for real.
-- A key counts only when its keymap really fires. Lessons run in a new tab with scratch
-- buffers (or a small practice project) and put everything back when they end.
local M = {}

local config = require("lazynator.config")
local groups = require("lazynator.groups")
local keys = require("lazynator.keys")
local progress = require("lazynator.progress")
local track = require("lazynator.track")
local ui = require("lazynator.ui")

local MIN, MAX = 3, 5

---@class lazynator.Step
---@field id string
---@field desc string
---@field needs? string
---@field tokens string[]
---@field lit integer
---@field state "todo"|"now"|"done"|"skip"

---@type table? the running lesson
local L

function M.active()
  return L ~= nil
end

local function main_win()
  if L and L.win and vim.api.nvim_win_is_valid(L.win) then
    return L.win
  end
  if L and L.tab and vim.api.nvim_tabpage_is_valid(L.tab) then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(L.tab)) do
      if vim.api.nvim_win_get_config(w).relative == "" then
        L.win = w
        return w
      end
    end
  end
end

local function normal_wins()
  local out = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(L.tab)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      out[#out + 1] = w
    end
  end
  return out
end

-- Run fn once you are back in a normal window in normal mode (not in a picker or Lazygit).
local function when_ready(fn)
  local me = L
  if not me then
    return
  end
  local ok = vim.api.nvim_get_current_tabpage() == me.tab
    and vim.api.nvim_win_get_config(0).relative == ""
    and vim.api.nvim_get_mode().mode == "n"
  if ok then
    return fn()
  end
  vim.defer_fn(function()
    if L == me then
      when_ready(fn)
    end
  end, 300)
end

-- Setup helpers ------------------------------------------------------------------

local function scratch(name, lines)
  local buf = vim.api.nvim_create_buf(true, true)
  pcall(vim.api.nvim_buf_set_name, buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "hide"
  L.scratch[#L.scratch + 1] = buf
  return buf
end

local function scratch_lines(n)
  return {
    ("Spacey's scratch buffer %d."):format(n),
    "Practice here. Nothing in this buffer is saved.",
    "",
    "keys are faster than the mouse",
  }
end

local function live_scratch()
  local out = {}
  for _, b in ipairs(L.scratch) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
      out[#out + 1] = b
    end
  end
  return out
end

-- Buffers lesson: at least 3 scratch buffers, and the window shows one of them.
local function ensure_buffers()
  local list = live_scratch()
  local n = #L.scratch
  while #list < 3 do
    n = n + 1
    list[#list + 1] = scratch(("spacey-%d"):format(n), scratch_lines(n))
  end
  local win = main_win()
  if win and not vim.tbl_contains(list, vim.api.nvim_win_get_buf(win)) then
    vim.api.nvim_win_set_buf(win, list[1])
  end
end

local function ensure_split()
  if #normal_wins() < 2 then
    local win = main_win()
    if win then
      vim.api.nvim_win_call(win, function()
        vim.cmd("vsplit")
      end)
    end
  end
end

local function git(dir, args)
  local cmd = { "git", "-C", dir, "-c", "user.name=Spacey", "-c", "user.email=spacey@localhost", "-c", "commit.gpgsign=false" }
  vim.list_extend(cmd, args)
  local ok, obj = pcall(function()
    return vim.system(cmd, { text = true }):wait(5000)
  end)
  return ok and obj.code == 0
end

-- A tiny project with git, so pickers, the tree, Lazygit and the LSP have something to show.
local function make_project()
  local dir = vim.fn.stdpath("cache") .. "/lazynator/practice"
  vim.fn.delete(dir, "rf")
  vim.fn.mkdir(dir .. "/src", "p")
  local files = {
    ["README.md"] = {
      "# Spacey's practice project",
      "",
      "A small project for Lazynator lessons. It is deleted when the lesson ends.",
      "",
      "TODO: find this line with a search key.",
    },
    ["notes.txt"] = { "spacey likes keys", "keys are faster than the mouse" },
    ["src/hello.lua"] = {
      "local function greet(name)",
      '  return "Hello, " .. name',
      "end",
      "",
      'print(greet("Spacey"))',
    },
  }
  for name, lines in pairs(files) do
    vim.fn.writefile(lines, dir .. "/" .. name)
  end
  if vim.fn.executable("git") == 1 then
    if git(dir, { "init", "-q" }) and git(dir, { "add", "-A" }) then
      git(dir, { "commit", "-q", "-m", "Practice project" })
    end
  end
  return dir
end

local function snap_toggles()
  local snap = {}
  local ok, Snacks = pcall(require, "snacks")
  local list = ok and type(Snacks) == "table" and Snacks.toggle and rawget(Snacks.toggle, "toggles")
  for id, t in pairs(type(list) == "table" and list or {}) do
    local okg, v = pcall(t.opts.get)
    if okg then
      snap[id] = v
    end
  end
  return snap
end

local function restore_toggles(snap)
  local ok, Snacks = pcall(require, "snacks")
  local list = ok and type(Snacks) == "table" and Snacks.toggle and rawget(Snacks.toggle, "toggles") or {}
  for id, v in pairs(snap) do
    local t = list[id]
    if t then
      local okg, cur = pcall(t.opts.get)
      if okg and cur ~= v then
        pcall(t.opts.set, v)
      end
    end
  end
end

-- Drawing ---------------------------------------------------------------------------

local function counts()
  local n = 0
  for _, s in ipairs(L.steps or {}) do
    if s.state == "done" then
      n = n + 1
    end
  end
  return n
end

local function group_learned()
  local list = keys.group_keys(L.group, keys.live(vim.api.nvim_win_is_valid(L.win or -1) and vim.api.nvim_win_get_buf(L.win) or nil))
  local n = 0
  for _, k in ipairs(list) do
    if progress.state(k.id) == "learned" then
      n = n + 1
    end
  end
  return n, #list
end

local function render()
  if not L or vim.api.nvim_get_current_tabpage() ~= L.tab then
    return
  end
  local lines
  if L.finished then
    local learned, total = group_learned()
    lines = ui.with_spacey("done", {
      { { L.group.name .. " lesson done!", "LazynatorTitle" } },
      { { ("%d of %d keys pressed for real."):format(counts(), #L.steps) } },
      { { ("%s learned: %d of %d"):format(L.group.name, learned, total), "LazynatorDim" } },
    })
  elseif L.empty then
    lines = ui.with_spacey("think", {
      { { L.group.name .. " lesson", "LazynatorTitle" } },
      { { "I found no keys for this group in your config." } },
      { { "Nothing to practice here.", "LazynatorDim" } },
    })
  elseif not L.steps then
    lines = ui.with_spacey("think", {
      { { L.group.name .. " lesson", "LazynatorTitle" } },
      { { "Getting ready..." } },
      { { "Waiting for the language server.", "LazynatorDim" } },
    })
  else
    lines = ui.with_spacey(L.mood, {
      { { L.group.name .. " lesson", "LazynatorTitle" } },
      { { "Press each key for real." } },
      { { "Typing the : command does not count.", "LazynatorDim" } },
    })
    lines[#lines + 1] = {}
    local capw, descw = 0, 0
    local caps = {}
    for i, s in ipairs(L.steps) do
      caps[i] = ui.caps(s.id, s.state == "now" and s.lit or 0, s.state == "done")
      local w = 0
      for _, seg in ipairs(caps[i]) do
        w = w + vim.api.nvim_strwidth(seg[1])
      end
      caps[i].w = w
      capw = math.max(capw, w)
      descw = math.max(descw, vim.api.nvim_strwidth(s.desc))
    end
    local need = config.options.learned_after
    for i, s in ipairs(L.steps) do
      local mark = ({
        done = { "✓ ", "LazynatorOk" },
        skip = { "- ", "LazynatorDim" },
        now = { "▸ ", "LazynatorAccent" },
      })[s.state] or { "  " }
      local line = { mark }
      vim.list_extend(line, caps[i])
      line[#line + 1] = { string.rep(" ", capw - caps[i].w + 2) }
      line[#line + 1] = { s.desc, s.state == "todo" and "LazynatorDim" or nil }
      line[#line + 1] = { string.rep(" ", descw - vim.api.nvim_strwidth(s.desc) + 2) }
      local p = progress.get(s.id)
      local learned = progress.state(s.id) == "learned"
      local tag = learned and "learned" or ("%d/%d"):format(math.min(p.streak, need), need)
      line[#line + 1] = { tag, learned and "LazynatorLearned" or "LazynatorDim" }
      lines[#lines + 1] = line
    end
    lines[#lines + 1] = {}
    lines[#lines + 1] = L.note and { L.note } or { { "If something opens, close it with Esc or q.", "LazynatorDim" } }
    lines[#lines + 1] = {
      { ("%d/%d done"):format(counts(), #L.steps), "LazynatorDim" },
      { "   :Lazynator skip   :Lazynator stop", "LazynatorDim" },
    }
  end
  ui.show(L.float, { pos = "bottom_left", lines = lines, title = "Lazynator" })
end

local function redraw()
  vim.schedule(render)
end

-- Flow ------------------------------------------------------------------------------

local finish

local function prepare(step)
  if L.group.setup == "buffers" then
    ensure_buffers()
  end
  if step.needs == "split" then
    ensure_split()
  end
end

local function go_to(i)
  L.cur = i
  local step = L.steps[i]
  if not step then
    return finish()
  end
  L.mood = "idle"
  step.state = "now"
  step.lit = 0
  -- Setup (scratch buffers, a split) waits until you are back from a picker or Lazygit.
  when_ready(function()
    if L and L.cur == i and step.state == "now" then
      prepare(step)
      render()
    end
  end)
  render()
end

finish = function()
  L.finished = true
  L.mood = "done"
  progress.save()
  render()
  local me = L
  vim.defer_fn(function()
    if L == me then
      M.stop()
      -- go on: the menu opens with the next lesson selected (Enter starts it)
      local next_i
      for i, g in ipairs(groups.list) do
        if g.id == me.group.id then
          next_i = i % #groups.list + 1
        end
      end
      require("lazynator.menu").open({ select = next_i })
    end
  end, 3500)
end

local function pick(list)
  local todo, learned = {}, {}
  for i, k in ipairs(list) do
    k.order = i
    if progress.state(k.id) == "learned" then
      learned[#learned + 1] = k
    else
      todo[#todo + 1] = k
    end
  end
  local out = {}
  for _, k in ipairs(todo) do
    if #out < MAX then
      out[#out + 1] = k
    end
  end
  for _, k in ipairs(learned) do
    if #out < MIN then
      out[#out + 1] = k
    end
  end
  table.sort(out, function(a, b)
    return a.order < b.order
  end)
  return out
end

local function build_steps()
  if not L or L.steps then
    return
  end
  local win = main_win()
  local buf = win and vim.api.nvim_win_get_buf(win) or vim.api.nvim_get_current_buf()
  track.refresh(buf)
  local chosen = pick(keys.group_keys(L.group, keys.live(buf)))
  if #chosen == 0 then
    L.empty = true
    render()
    local me = L
    vim.defer_fn(function()
      if L == me then
        M.stop()
      end
    end, 3500)
    return
  end
  L.steps = {}
  for _, k in ipairs(chosen) do
    L.steps[#L.steps + 1] = {
      id = k.id,
      desc = k.desc ~= "" and k.desc or keys.text(k.id),
      needs = k.needs,
      tokens = keys.typed_tokens(k.id),
      lit = 0,
      state = "todo",
    }
  end
  go_to(1)
end

-- Light up keycaps as you type.
local function on_typed(t)
  local s = L and L.steps and L.steps[L.cur]
  if not s or s.state ~= "now" then
    return
  end
  for _, tok in ipairs(keys.split(t)) do
    if s.lit < #s.tokens and s.tokens[s.lit + 1] == tok then
      s.lit = s.lit + 1
    elseif s.tokens[1] == tok then
      s.lit = 1
    else
      s.lit = 0
    end
  end
  redraw()
end

local function on_press(id)
  local s = L and L.steps and L.steps[L.cur]
  if not s or s.state ~= "now" or s.id ~= id then
    return
  end
  s.state = "done"
  s.lit = #s.tokens
  L.mood = "happy"
  L.note = { "Yes! That was a real press.", "LazynatorOk" }
  redraw()
  local me, i = L, L.cur
  vim.defer_fn(function()
    if L == me and L.cur == i then
      L.note = nil
      go_to(i + 1)
    end
  end, 700)
end

local function on_nudge(id)
  local s = L and L.steps and L.steps[L.cur]
  if s and s.state == "now" and s.id == id then
    L.mood = "think"
    L.note = { "That was the slow way. It does not count.", "LazynatorWarn" }
    redraw()
  end
end

---@param group_id string
function M.start(group_id)
  local group = groups.get(group_id)
  if not group then
    local ids = vim.tbl_map(function(g)
      return g.id
    end, groups.list)
    vim.notify("Lazynator: no lesson called '" .. tostring(group_id) .. "'. Try: " .. table.concat(ids, ", "))
    return
  end
  if L then
    M.stop()
  end
  require("lazynator").start()

  local orig = {
    tab = vim.api.nvim_get_current_tabpage(),
    win = vim.api.nvim_get_current_win(),
    listed = {},
    cwd = vim.fn.getcwd(),
    wins = {},
  }
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted then
      orig.listed[b] = vim.api.nvim_buf_get_name(b)
    end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(orig.tab)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      local b = vim.api.nvim_win_get_buf(w)
      orig.wins[w] = { buf = b, name = vim.api.nvim_buf_get_name(b), cursor = vim.api.nvim_win_get_cursor(w) }
    end
  end

  L = { group = group, orig = orig, scratch = {}, added = {}, float = {}, unsub = {}, mood = "idle" }
  L.augroup = vim.api.nvim_create_augroup("lazynator.lesson", { clear = true })
  vim.api.nvim_create_autocmd("BufNew", {
    group = L.augroup,
    callback = function(ev)
      if L then
        L.added[ev.buf] = true
      end
    end,
  })

  vim.cmd("tabnew")
  L.tab = vim.api.nvim_get_current_tabpage()
  L.win = vim.api.nvim_get_current_win()
  local first = vim.api.nvim_get_current_buf()

  if group.setup == "project" then
    L.dir = make_project()
    vim.cmd("tcd " .. vim.fn.fnameescape(L.dir))
    vim.cmd("edit " .. vim.fn.fnameescape(L.dir .. "/" .. (group.file or "README.md")))
  else
    vim.api.nvim_win_set_buf(L.win, scratch("spacey-1", scratch_lines(1)))
  end
  if vim.api.nvim_buf_is_valid(first) and first ~= vim.api.nvim_get_current_buf() then
    pcall(vim.api.nvim_buf_delete, first, { force = true })
  end
  L.toggles = snap_toggles()
  L.colors = vim.g.colors_name

  L.unsub[#L.unsub + 1] = track.on_key(on_typed)
  L.unsub[#L.unsub + 1] = track.on_press(on_press)
  L.unsub[#L.unsub + 1] = require("lazynator.nudge").on_nudge(on_nudge)
  vim.api.nvim_create_autocmd({ "TabEnter", "VimResized" }, { group = L.augroup, callback = redraw })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = L.augroup,
    callback = function()
      if L and not vim.api.nvim_tabpage_is_valid(L.tab) then
        vim.schedule(M.stop)
      end
    end,
  })

  local function lsp_expected(b)
    if vim.lsp.get_configs then
      local ok, list = pcall(vim.lsp.get_configs, { enabled = true, filetype = vim.bo[b].filetype })
      if ok then
        return #list > 0
      end
    end
    return true
  end
  local buf = vim.api.nvim_get_current_buf()
  if group.lsp and #vim.lsp.get_clients({ bufnr = buf }) == 0 and lsp_expected(buf) then
    -- Wait a moment for the language server, so its keys (code action, rename) are there.
    render()
    local me = L
    local function go()
      if L == me and not L.steps then
        build_steps()
      end
    end
    vim.api.nvim_create_autocmd("LspAttach", {
      group = L.augroup,
      buffer = buf,
      once = true,
      callback = function()
        vim.defer_fn(go, 300)
      end,
    })
    vim.defer_fn(go, 3000)
  else
    build_steps()
  end
end

--- Skip the current key.
function M.skip()
  local s = L and L.steps and L.steps[L.cur]
  if s then
    s.state = "skip"
    L.note = nil
    go_to(L.cur + 1)
  end
end

--- End the lesson and put everything back.
function M.stop()
  if not L then
    return
  end
  local S = L
  L = nil
  for _, f in ipairs(S.unsub) do
    f()
  end
  pcall(vim.api.nvim_del_augroup_by_id, S.augroup)
  ui.close(S.float)

  -- Terminals the lesson opened (Lazygit, a shell) stop when their window closes below.
  -- Their "exited with code" warning would look like an error, so remove it first.
  for b in pairs(S.added) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "terminal" then
      for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "TermClose", buffer = b })) do
        pcall(vim.api.nvim_del_autocmd, au.id)
      end
    end
  end

  -- Put toggles and the colorscheme back while still in the lesson tab.
  if vim.api.nvim_tabpage_is_valid(S.tab) then
    pcall(vim.api.nvim_set_current_tabpage, S.tab)
  end
  if S.colors and vim.g.colors_name ~= S.colors then
    pcall(vim.cmd.colorscheme, S.colors)
  end
  restore_toggles(S.toggles or {})

  -- Close the lesson tab. If your own tab is gone (a key closed its last window), keep this one.
  if vim.api.nvim_tabpage_is_valid(S.orig.tab) then
    if vim.api.nvim_tabpage_is_valid(S.tab) and S.tab ~= S.orig.tab then
      pcall(vim.cmd, "tabclose! " .. vim.api.nvim_tabpage_get_number(S.tab))
    end
    vim.api.nvim_set_current_tabpage(S.orig.tab)
  elseif vim.api.nvim_tabpage_is_valid(S.tab) then
    pcall(vim.cmd, "silent! only")
    pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(S.orig.cwd))
  end

  -- Bring back your own buffers if a lesson key closed them, and show them where they were.
  for b, name in pairs(S.orig.listed) do
    if not (vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted) and name ~= "" then
      local nb = vim.fn.bufadd(name)
      vim.bo[nb].buflisted = true
    end
  end
  for w, info in pairs(S.orig.wins) do
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) ~= info.buf then
      local b = info.buf
      if not (vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted) and info.name ~= "" then
        b = vim.fn.bufadd(info.name)
      end
      if vim.api.nvim_buf_is_valid(b) then
        pcall(vim.api.nvim_win_set_buf, w, b)
        pcall(vim.api.nvim_win_set_cursor, w, info.cursor)
      end
    end
  end

  -- Remove buffers the lesson made or opened: scratch and practice files, terminals it left
  -- running, and buffers you opened (never ones with unsaved changes of yours).
  -- First move any window that still shows one to a buffer of yours, so no window or tab closes.
  local doomed = {}
  for _, b in ipairs(S.scratch) do
    if vim.api.nvim_buf_is_valid(b) then
      doomed[b] = "force"
    end
  end
  for b in pairs(S.added) do
    if vim.api.nvim_buf_is_valid(b) and not S.orig.listed[b] and not doomed[b] then
      local name = vim.api.nvim_buf_get_name(b)
      if vim.bo[b].buftype == "terminal" or (S.dir and name:sub(1, #S.dir + 1) == S.dir .. "/") then
        doomed[b] = "force"
      elseif vim.bo[b].buflisted and not vim.bo[b].modified then
        doomed[b] = true
      end
    end
  end
  local keep
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if not keep and not doomed[b] and vim.bo[b].buflisted then
      keep = b
    end
  end
  for b in pairs(doomed) do
    for _, w in ipairs(vim.fn.win_findbuf(b)) do
      if vim.api.nvim_win_get_config(w).relative == "" then
        keep = keep or vim.api.nvim_create_buf(true, false)
        pcall(vim.api.nvim_win_set_buf, w, keep)
      end
    end
  end
  for b, how in pairs(doomed) do
    pcall(vim.api.nvim_buf_delete, b, { force = how == "force" })
  end

  if vim.api.nvim_win_is_valid(S.orig.win) then
    pcall(vim.api.nvim_set_current_win, S.orig.win)
  end
  if S.dir then
    vim.fn.delete(S.dir, "rf")
  end
  progress.save()
end

return M
