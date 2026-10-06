-- Live keymap reader. Normal mode only.
-- A key id is the keytrans() form of the lhs, with the leader written as "<leader>".
local M = {}

local function leader_raw()
  local l = vim.g.mapleader
  if l == nil then
    l = "\\"
  end
  return vim.keycode(l)
end

---@param raw string lhs as raw bytes
function M.id_raw(raw)
  local lr = leader_raw()
  if lr ~= "" and #raw > #lr and raw:sub(1, #lr) == lr then
    return "<leader>" .. vim.fn.keytrans(raw:sub(#lr + 1))
  end
  return vim.fn.keytrans(raw)
end

---@param lhs string lhs in <> notation, e.g. "<leader>bd" or "<S-l>"
function M.id(lhs)
  return M.id_raw(vim.keycode(lhs))
end

--- Split a keytrans string into one token per key press.
---@return string[]
function M.split(s)
  local out, i = {}, 1
  while i <= #s do
    local tok = s:match("^<[^<>]+>", i)
    if not tok then
      tok = s:match("^[%z\1-\127\194-\244][\128-\191]*", i) or s:sub(i, i)
    end
    out[#out + 1] = tok
    i = i + #tok
  end
  return out
end

--- Tokens as they arrive from vim.on_key (leader expanded).
function M.typed_tokens(id)
  local out = {}
  for _, tok in ipairs(M.split(id)) do
    if tok == "<leader>" then
      vim.list_extend(out, M.split(vim.fn.keytrans(leader_raw())))
    else
      out[#out + 1] = tok
    end
  end
  return out
end

local names = {
  Space = "Space", CR = "Enter", Esc = "Esc", Tab = "Tab", BS = "Backspace", lt = "Less than",
  Bslash = "Backslash", Bar = "Bar", Up = "Up", Down = "Down", Left = "Left", Right = "Right",
  Del = "Delete", Home = "Home", End = "End", PageUp = "PageUp", PageDown = "PageDown",
}
-- Symbol keys get a name: "[`]" or "[]]" in a keycap is hard to read.
local symbols = {
  ["`"] = "Backtick", ["'"] = "Quote", ['"'] = "Double quote", ["["] = "Left bracket",
  ["]"] = "Right bracket", ["{"] = "Left brace", ["}"] = "Right brace", ["("] = "Left paren",
  [")"] = "Right paren", [","] = "Comma", ["."] = "Period", ["/"] = "Slash", ["\\"] = "Backslash",
  ["|"] = "Bar", ["-"] = "Minus", ["_"] = "Underscore", ["="] = "Equals", ["+"] = "Plus",
  [";"] = "Semicolon", [":"] = "Colon", ["<"] = "Less than", [">"] = "Greater than",
  ["?"] = "Question mark", ["!"] = "Exclamation mark", ["*"] = "Star", ["#"] = "Hash",
  ["~"] = "Tilde", ["^"] = "Caret", ["%"] = "Percent", ["&"] = "Ampersand", ["@"] = "At",
  ["$"] = "Dollar",
}
local mods = { C = "Ctrl", M = "Alt", A = "Alt", S = "Shift", D = "Super" }

local function key_name(k)
  if names[k] then
    return names[k]
  end
  if symbols[k] then
    return symbols[k]
  end
  if #k == 1 then
    return k:lower()
  end
  return k
end

--- Human label for one token: "<C-H>" -> "Ctrl h", "L" -> "Shift l".
function M.label(tok)
  if tok == "<leader>" then
    return table.concat(vim.tbl_map(M.label, M.split(vim.fn.keytrans(leader_raw()))), " ")
  end
  local inner = tok:match("^<(.+)>$")
  if inner then
    if names[inner] then
      return names[inner]
    end
    local parts = {}
    local rest = inner
    while true do
      local m, r = rest:match("^(%u)%-(.+)$")
      if not m or not mods[m] then
        break
      end
      parts[#parts + 1] = mods[m]
      rest = r
    end
    if #parts > 0 then
      parts[#parts + 1] = key_name(rest)
      return table.concat(parts, " ")
    end
    return inner
  end
  if tok:match("^%u$") then
    return "Shift " .. tok:lower()
  end
  return symbols[tok] or tok
end

---@return string[] one label per key press
function M.labels(id)
  return vim.tbl_map(M.label, M.split(id))
end

--- "Space b d"
function M.text(id)
  return table.concat(M.labels(id), " ")
end

-- which-key descriptions, used only when a keymap has no desc of its own.
local wk_cache, wk_list, wk_len
local function wk_descs()
  local cfg = package.loaded["which-key.config"]
  local list = cfg and rawget(cfg, "mappings")
  if type(list) ~= "table" then
    return {}
  end
  if wk_cache and wk_list == list and wk_len == #list then
    return wk_cache
  end
  local out = {}
  for _, km in ipairs(list) do
    local desc = km.desc
    if type(desc) == "function" then
      local ok, d = pcall(desc)
      desc = ok and d or nil
    end
    if type(desc) == "string" and desc ~= "" and type(km.lhs) == "string" and not km.group
      and (km.mode == nil or km.mode == "n") then
      local ok, id = pcall(M.id, km.lhs)
      if ok then
        out[id] = desc
      end
    end
  end
  wk_cache, wk_list, wk_len = out, list, #list
  return out
end

local function skip(m)
  if m.lhs:find("<Plug>", 1, true) == 1 then
    return true
  end
  if not m.callback and (m.rhs == nil or m.rhs == "") then
    return true -- which-key group placeholder
  end
  local d = m.desc or ""
  return d:sub(1, 1) == "+" or d == "which_key_ignore"
end

--- Wrapper function -> the keymap it replaced (filled by lazynator.track).
---@type table<function, table>
M.wrapped = setmetatable({}, { __mode = "k" })

---@class lazynator.Key
---@field id string
---@field desc string
---@field map table raw keymap dict, as it is now
---@field rhs string? right-hand side text of the original keymap (before wrapping)
---@field wrapped boolean
---@field buf integer? buffer for a buffer-local keymap

--- Normal-mode keymaps as a list: global ones, then buffer-local ones of `buf`.
---@param buf? integer
---@param local_only? boolean only buffer-local keymaps
---@return lazynator.Key[]
function M.entries(buf, local_only)
  buf = buf or vim.api.nvim_get_current_buf()
  local out = {}
  local function add(m, b)
    if skip(m) then
      return
    end
    local id = M.id_raw(m.lhsraw or vim.keycode(m.lhs))
    local orig = m.callback and M.wrapped[m.callback]
    out[#out + 1] = {
      id = id,
      desc = m.desc or wk_descs()[id] or "",
      map = m,
      rhs = (orig or m).rhs,
      wrapped = orig ~= nil,
      buf = b,
    }
  end
  if not local_only then
    for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
      add(m)
    end
  end
  if vim.api.nvim_buf_is_valid(buf) then
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      add(m, buf)
    end
  end
  return out
end

--- Live normal-mode keymaps by id. Buffer-local ones win over global ones.
---@param buf? integer
---@return table<string, lazynator.Key>
function M.live(buf)
  local res = {}
  for _, k in ipairs(M.entries(buf)) do
    res[k.id] = k
  end
  return res
end

local function lower_first(a, b)
  local la, lb = a.id:lower(), b.id:lower()
  if la ~= lb then
    return la < lb
  end
  return a.id > b.id
end

---@class lazynator.GroupKey
---@field id string
---@field desc string
---@field needs string?
---@field key lazynator.Key

--- Keys of a group in lesson order: listed keys first, then other live keys under the prefix.
---@param group table from groups.list
---@param live table<string, lazynator.Key>
---@return lazynator.GroupKey[]
function M.group_keys(group, live)
  local ignore, seen, out = {}, {}, {}
  for _, lhs in ipairs(group.ignore or {}) do
    ignore[M.id(lhs)] = true
  end
  for _, item in ipairs(group.keys) do
    local lhs = type(item) == "table" and item[1] or item
    local id = M.id(lhs)
    local k = live[id]
    if k and not seen[id] and not ignore[id] then
      seen[id] = true
      out[#out + 1] = { id = id, desc = k.desc, needs = type(item) == "table" and item.needs or nil, key = k }
    end
  end
  local prefix = "<leader>" .. group.prefix
  local extra = {}
  for id, k in pairs(live) do
    if not seen[id] and not ignore[id] and #id > #prefix and id:sub(1, #prefix) == prefix then
      extra[#extra + 1] = { id = id, desc = k.desc, key = k }
    end
  end
  table.sort(extra, lower_first)
  vim.list_extend(out, extra)
  return out
end

local index, index_leader

--- Ids from the built-in lists, cached until the leader changes.
---@return {group:table<string,string>, ignore:table<string,boolean>, other:table<string,boolean>}
function M.index()
  local lr = leader_raw()
  if index and index_leader == lr then
    return index
  end
  local G = require("lazynator.groups")
  local idx = { group = {}, ignore = {}, other = {}, pos = {} }
  local n = 0
  for _, g in ipairs(G.list) do
    for _, item in ipairs(g.keys) do
      local id = M.id(type(item) == "table" and item[1] or item)
      idx.group[id] = idx.group[id] or g.id
      n = n + 1
      idx.pos[id] = idx.pos[id] or n
    end
    for _, lhs in ipairs(g.ignore or {}) do
      idx.ignore[M.id(lhs)] = true
    end
  end
  local function other(list)
    for _, lhs in ipairs(type(list) == "table" and list or { list }) do
      idx.other[M.id(lhs)] = true
    end
  end
  for _, s in ipairs(G.slow) do
    other(s.key)
  end
  for _, list in pairs(G.mouse) do
    other(list)
  end
  index, index_leader = idx, lr
  return idx
end

--- Group id for a key id, or nil.
function M.group_of(id)
  local idx = M.index()
  if idx.group[id] then
    return idx.group[id]
  end
  if idx.ignore[id] then
    return nil
  end
  for _, g in ipairs(require("lazynator.groups").list) do
    local prefix = "<leader>" .. g.prefix
    if #id > #prefix and id:sub(1, #prefix) == prefix then
      return g.id
    end
  end
end

--- First id from a list of lhs that exists live.
---@param list string|string[]
---@param live table<string, lazynator.Key>
function M.first(list, live)
  for _, lhs in ipairs(type(list) == "table" and list or { list }) do
    local id = M.id(lhs)
    if live[id] then
      return id
    end
  end
end

return M
