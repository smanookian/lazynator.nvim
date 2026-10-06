local lesson = require("lazynator.lesson")
local progress = require("lazynator.progress")

local function type_keys(s)
  vim.api.nvim_feedkeys(vim.keycode(s), "mtx", false)
end

--- Text of the lesson window, or nil.
local function panel()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype == "lazynator" then
      local text = table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
      if text:find("lesson") or text:find("review") then
        return text
      end
    end
  end
end

local function has(pattern)
  return function()
    local p = panel()
    return p ~= nil and p:find(pattern, 1, true) ~= nil
  end
end

local function listed_names()
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted then
      out[#out + 1] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t")
    end
  end
  table.sort(out)
  return out
end

local function normal_wins()
  return #vim.tbl_filter(function(w)
    return vim.api.nvim_win_get_config(w).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
end

describe("lessons", function()
  before_each(function()
    lesson.stop()
    vim.cmd("silent! tabonly | silent! only")
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
    vim.cmd("edit mine-1.txt | edit mine-2.txt")
    progress.reset()
  end)

  it("does not ask finished keys again: the next round has the next keys", function()
    -- buffers keys in tests/init.lua: L, H, <leader>bd, <leader>, , <leader>bb, <leader>bo, <leader>bD
    for _, id in ipairs({ "L", "H", "<leader>bd", "<leader>,", "<leader>bb" }) do
      progress.done(id)
    end
    lesson.start("buffers")
    truthy(wait_for(has("Buffers lesson")), panel())
    local p = panel()
    eq(nil, p:find("[Shift l]", 1, true))
    truthy(p:find("▸ [Space] [b] [o]", 1, true), p)
    truthy(p:find("[Space] [b] [Shift d]", 1, true), p)
  end)

  it("marks a key done only when it really fired, not when skipped", function()
    lesson.start("buffers")
    truthy(wait_for(has("▸ [Shift l]")))
    type_keys("<S-l>")
    truthy(wait_for(has("▸ [Shift h]")))
    lesson.skip()
    eq(true, progress.is_done("L"))
    eq(false, progress.is_done("H"))
  end)

  local function buffer_keys()
    local keys = require("lazynator.keys")
    return vim.tbl_map(function(k)
      return k.id
    end, keys.group_keys(require("lazynator.groups").get("buffers"), keys.live()))
  end

  it("when every key is done: a review of the keys not learned yet", function()
    for _, id in ipairs(buffer_keys()) do
      progress.done(id)
    end
    for _ = 1, 5 do
      progress.press("L") -- learned now
    end
    lesson.start("buffers")
    truthy(wait_for(has("Buffers review")), panel())
    eq(nil, panel():find("[Shift l]", 1, true))
    truthy(panel():find("▸ [Shift h]", 1, true), panel())
  end)

  it("when every key is done and learned: says so", function()
    for _, id in ipairs(buffer_keys()) do
      progress.done(id)
      for _ = 1, 5 do
        progress.press(id)
      end
    end
    lesson.start("buffers")
    truthy(wait_for(has("You learned every key here!")), panel())
  end)

  it("after a reset the keys come back", function()
    progress.done("L")
    progress.reset()
    lesson.start("buffers")
    truthy(wait_for(has("▸ [Shift l]")), panel())
  end)

  it("opens in a new tab with scratch buffers and shows 3-5 keys from your config", function()
    local tab = vim.api.nvim_get_current_tabpage()
    lesson.start("buffers")
    truthy(tab ~= vim.api.nvim_get_current_tabpage(), "new tab")
    truthy(wait_for(has("Buffers lesson")), panel())
    local p = panel()
    truthy(p:find("▸ [Shift l]", 1, true), p)
    truthy(p:find("[Space] [b] [d]  Delete Buffer", 1, true), p)
    eq({ "mine-1.txt", "mine-2.txt", "spacey-1", "spacey-2", "spacey-3" }, listed_names())
  end)

  it("counts only a real press: the : command does not move it on, the key does", function()
    lesson.start("buffers")
    truthy(wait_for(has("▸ [Shift l]")))
    type_keys(":bnext<CR>")
    vim.wait(100)
    truthy(has("▸ [Shift l]")(), panel())
    truthy(wait_for(has("That was the slow way")), panel())
    type_keys("<S-l>")
    truthy(wait_for(has("✓ [Shift l]")), panel())
    truthy(wait_for(has("▸ [Shift h]")), panel())
    type_keys("<S-h>")
    truthy(wait_for(has("✓ [Shift h]")), panel())
  end)

  it("lights up keycaps as you type", function()
    lesson.start("buffers")
    lesson.skip()
    lesson.skip()
    truthy(wait_for(has("▸ [Space] [b] [d]")))
    local caps_lit = function()
      local b
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "lazynator" then
          b = vim.api.nvim_win_get_buf(w)
        end
      end
      local n = 0
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, -1, 0, -1, { details = true })) do
        if m[4].hl_group == "LazynatorCapLit" then
          n = n + 1
        end
      end
      return n
    end
    eq(0, caps_lit())
    type_keys("<Space>b") -- not complete yet: <leader>b is a prefix
    truthy(wait_for(function()
      return caps_lit() == 2
    end), "two caps lit")
    type_keys("<Esc>")
  end)

  it("ends by putting back the tab, your buffers and the window", function()
    local tab, win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
    lesson.start("buffers")
    truthy(wait_for(has("Buffers lesson")))
    type_keys("<leader>bo") -- deletes your own buffers too
    eq(false, vim.tbl_contains(listed_names(), "mine-1.txt"))
    eq(false, vim.tbl_contains(listed_names(), "mine-2.txt"))
    lesson.stop()
    eq(tab, vim.api.nvim_get_current_tabpage())
    eq(win, vim.api.nvim_get_current_win())
    eq(1, #vim.api.nvim_list_tabpages())
    eq({ "mine-1.txt", "mine-2.txt" }, listed_names())
    eq("mine-2.txt", vim.fn.expand("%:t"))
  end)

  it("reads keymaps live: a changed keymap shows up in the next lesson", function()
    vim.keymap.set("n", "<leader>bd", function()
      vim.cmd("bdelete")
    end, { desc = "Close This Buffer" })
    vim.keymap.del("n", "<S-l>")
    lesson.start("buffers")
    truthy(wait_for(has("Close This Buffer")), panel())
    eq(nil, panel():find("[Shift l]", 1, true))
    lesson.stop()
    vim.keymap.set("n", "<S-l>", "<Cmd>bnext<CR>", { desc = "Next Buffer" })
    vim.keymap.set("n", "<leader>bd", function()
      vim.cmd("bdelete")
    end, { desc = "Delete Buffer" })
  end)

  it("makes a split before a key that needs two windows", function()
    lesson.start("windows")
    truthy(wait_for(has("▸ [Space] [|]")), panel())
    eq(1, normal_wins())
    lesson.skip()
    truthy(wait_for(has("▸ [Ctrl h]")), panel())
    truthy(wait_for(function()
      return normal_wins() == 2
    end), "two windows")
    type_keys("<C-h>")
    truthy(wait_for(has("✓ [Ctrl h]")), panel())
  end)

  it("finishes after the last key and closes itself", function()
    progress.reload()
    lesson.start("code")
    truthy(wait_for(has("▸ ["), 5000), panel())
    for _ = 1, 5 do
      lesson.skip()
    end
    truthy(wait_for(has("lesson done!")), panel())
    truthy(wait_for(function()
      return not lesson.active()
    end, 5000))
    eq(1, #vim.api.nvim_list_tabpages())
    eq(0, vim.fn.isdirectory(vim.fn.stdpath("cache") .. "/lazynator/practice"))
  end)

  it("starts every group and cleans up", function()
    for _, id in ipairs({ "buffers", "files", "search", "git", "code", "toggles", "windows" }) do
      lesson.start(id)
      truthy(wait_for(function()
        local p = panel()
        return p ~= nil and p:find("▸ %[") ~= nil
      end, 4000), id .. ": " .. tostring(panel()))
      lesson.stop()
      eq(1, #vim.api.nvim_list_tabpages())
      eq({ "mine-1.txt", "mine-2.txt" }, listed_names())
    end
  end)
end)
