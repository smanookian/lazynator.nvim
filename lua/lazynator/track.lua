-- Counts real key presses.
-- Each tracked keymap is wrapped: the wrapper reports the press, then runs the original.
-- Wrapping is redone when keymaps may have changed (plugin loads, :source, LSP attach, buffer enter).
local M = {}

local keys = require("lazynator.keys")
local progress = require("lazynator.progress")

local typed_seq = 0
local counted_at = {} ---@type table<string, integer>
local press_listeners = {} ---@type fun(id:string)[]
local key_listeners = {} ---@type fun(typed:string, key:string)[]
local started = false

--- True when the last ":" that opened the command line was typed by you (not sent by a keymap).
M.cmd_typed = false

local function add_listener(list, fn)
  list[#list + 1] = fn
  return function()
    for i, f in ipairs(list) do
      if f == fn then
        table.remove(list, i)
        return
      end
    end
  end
end

--- Called with the key id each time a tracked keymap really fires.
---@return fun() unsubscribe
function M.on_press(fn)
  return add_listener(press_listeners, fn)
end

--- Called for every key you type: fn(keytrans of the typed key, key, raw typed bytes).
--- If fn returns true, the key is held back (fn must run it again itself).
---@return fun() unsubscribe
function M.on_key(fn)
  return add_listener(key_listeners, fn)
end

--- Report a press. One typed key sequence counts once, even if lazy.nvim replays it.
function M.fire(id)
  if counted_at[id] == typed_seq then
    return
  end
  counted_at[id] = typed_seq
  progress.press(id)
  for _, fn in ipairs(press_listeners) do
    pcall(fn, id)
  end
end

function M.is_tracked(id)
  return keys.group_of(id) ~= nil or keys.index().other[id] or progress.all()[id] ~= nil
end

---@param k lazynator.Key
---@return boolean wrapped
local function wrap(k)
  local m = k.map
  if k.wrapped or m.script == 1 then
    return false
  end
  local id = k.id
  local fn, expr, replace
  if m.callback then
    local orig = m.callback
    fn = function(...)
      M.fire(id)
      return orig(...)
    end
    expr, replace = m.expr == 1, m.replace_keycodes == 1
  elseif m.expr == 1 then
    if m.rhs:find("<SID>", 1, true) or m.rhs:find("s:", 1, true) then
      return false
    end
    local rhs = m.rhs
    fn = function()
      M.fire(id)
      return vim.api.nvim_eval(rhs)
    end
    expr, replace = true, false
  else
    local rhs = m.rhs:gsub("<SID>", ("<SNR>%d_"):format(m.sid or 0))
    fn = function()
      M.fire(id)
      return rhs
    end
    expr, replace = true, true
  end
  keys.wrapped[fn] = m
  vim.keymap.set("n", m.lhs, fn, {
    buffer = k.buf,
    desc = m.desc,
    silent = m.silent == 1,
    nowait = m.nowait == 1,
    remap = m.noremap == 0,
    expr = expr,
    replace_keycodes = replace,
  })
  return true
end

--- Wrap all tracked keymaps that are not wrapped yet.
---@param buf? integer
---@param buffer_only? boolean only look at buffer-local keymaps
---@return integer count newly wrapped
function M.refresh(buf, buffer_only)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return 0
  end
  local n = 0
  for _, k in ipairs(keys.entries(buf, buffer_only)) do
    if M.is_tracked(k.id) and wrap(k) then
      n = n + 1
    end
  end
  return n
end

--- Make sure one key is wrapped (used when a nudge points to a key outside the groups).
function M.ensure(id)
  for _, k in ipairs(keys.entries()) do
    if k.id == id then
      wrap(k)
    end
  end
end

local function on_key(key, typed)
  if key == ":" then
    local t = typed and vim.fn.keytrans(typed) or ""
    M.cmd_typed = t == ":" or (t ~= "" and vim.fn.maparg(t, "n") == ":")
  end
  if not typed or typed == "" then
    return
  end
  typed_seq = typed_seq + 1
  if #key_listeners == 0 then
    return
  end
  local t = vim.fn.keytrans(typed)
  local hold = false
  for _, fn in ipairs(key_listeners) do
    local ok, r = pcall(fn, t, key, typed)
    hold = hold or (ok and r == true)
  end
  if hold then
    return "" -- a listener took this key (it runs it again later)
  end
end

function M.start()
  if started then
    return
  end
  started = true
  vim.on_key(on_key, vim.api.nvim_create_namespace("lazynator"))
  M.refresh()

  local group = vim.api.nvim_create_augroup("lazynator.track", { clear = true })
  local queued = false
  local function later()
    if queued then
      return
    end
    queued = true
    vim.schedule(function()
      queued = false
      M.refresh()
    end)
  end
  vim.api.nvim_create_autocmd("User", { group = group, pattern = { "LazyLoad", "LazyReload" }, callback = later })
  vim.api.nvim_create_autocmd("SourcePost", { group = group, callback = later })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
      vim.defer_fn(function()
        M.refresh(ev.buf, true)
      end, 50)
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      vim.schedule(function()
        M.refresh(ev.buf, true)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = progress.save })
end

return M
