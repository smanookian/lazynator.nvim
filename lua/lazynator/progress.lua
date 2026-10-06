-- Progress per key, saved as JSON in stdpath("data")/lazynator/progress.json.
-- Changes are kept as a list of steps and replayed on top of the file when saving,
-- so two Neovim windows open at the same time do not overwrite each other.
local M = {}

local uv = vim.uv or vim.loop
local data ---@type {version:integer, keys:table<string, lazynator.Progress>}?
local pending = {} ---@type {id:string, kind:"press"|"nudge"|"done", t:integer}[]
local timer

---@class lazynator.Progress
---@field presses integer real presses, all time
---@field streak integer real presses since the last nudge
---@field nudges integer
---@field last_press? integer
---@field last_nudge? integer
---@field done? boolean pressed for real in a lesson

function M.path()
  return vim.fn.stdpath("data") .. "/lazynator/progress.json"
end

local function read_disk()
  local fresh = { version = 1, keys = {} }
  local f = io.open(M.path(), "r")
  if not f then
    return fresh
  end
  local s = f:read("*a")
  f:close()
  local ok, d = pcall(vim.json.decode, s)
  if not ok or type(d) ~= "table" or type(d.keys) ~= "table" then
    return fresh
  end
  return d
end

local function apply(d, op)
  local k = d.keys[op.id] or { presses = 0, streak = 0, nudges = 0 }
  d.keys[op.id] = k
  if op.kind == "press" then
    k.presses = k.presses + 1
    k.streak = k.streak + 1
    k.last_press = op.t
  elseif op.kind == "done" then
    k.done = true
  else
    k.nudges = k.nudges + 1
    k.streak = 0
    k.last_nudge = op.t
  end
end

local function load()
  if not data then
    data = read_disk()
  end
  return data
end

local function write(d)
  local path = M.path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local tmp = ("%s.%d.tmp"):format(path, uv.os_getpid())
  local f = io.open(tmp, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(next(d.keys) and d or { version = 1, keys = vim.empty_dict() }))
  f:close()
  uv.fs_rename(tmp, path)
  data = d
end

function M.save()
  if timer then
    timer:stop()
  end
  if #pending == 0 then
    return
  end
  local d = read_disk()
  for _, op in ipairs(pending) do
    apply(d, op)
  end
  write(d)
  pending = {}
end

--- Forget progress: all keys, or only the given key ids. Saved right away.
---@param ids? string[]
function M.reset(ids)
  M.save()
  local d = read_disk()
  if ids then
    for _, id in ipairs(ids) do
      d.keys[id] = nil
    end
  else
    d.keys = {}
  end
  write(d)
end

local function record(id, kind)
  local op = { id = id, kind = kind, t = os.time() }
  apply(load(), op)
  pending[#pending + 1] = op
  timer = timer or uv.new_timer()
  timer:stop()
  timer:start(2000, 0, vim.schedule_wrap(M.save))
end

function M.press(id)
  record(id, "press")
end

function M.nudge(id)
  record(id, "nudge")
end

--- The key was pressed for real in a lesson: it does not come up in new lessons again.
function M.done(id)
  if not M.is_done(id) then
    record(id, "done")
  end
end

function M.is_done(id)
  local k = load().keys[id]
  return k ~= nil and k.done == true
end

---@return lazynator.Progress
function M.get(id)
  return load().keys[id] or { presses = 0, streak = 0, nudges = 0 }
end

---@return "new"|"learning"|"learned"
function M.state(id)
  local k = load().keys[id]
  if not k or (k.presses == 0 and k.nudges == 0) then
    return "new"
  end
  if k.streak >= require("lazynator.config").options.learned_after then
    return "learned"
  end
  return "learning"
end

---@return table<string, lazynator.Progress>
function M.all()
  return load().keys
end

--- Forget the in-memory copy (the file is read again on next use).
function M.reload()
  M.save()
  data = nil
end

return M
