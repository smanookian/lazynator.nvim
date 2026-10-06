local config = require("lazynator.config")
local nudge = require("lazynator.nudge")
local progress = require("lazynator.progress")

local function type_keys(s)
  vim.api.nvim_feedkeys(vim.keycode(s), "mtx", false)
end

local function hint_text()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype == "lazynator" then
      return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
    end
  end
end

local function close_hints()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "lazynator" then
      vim.api.nvim_win_close(w, true)
    end
  end
end

--- Collect the keys nudged while fn runs.
local function nudged(fn, ms)
  local got = {}
  local off = nudge.on_nudge(function(id)
    got[#got + 1] = id
  end)
  fn()
  vim.wait(ms or 100)
  off()
  return got
end

describe("matching typed commands", function()
  it("uses the built-in slow-way list first", function()
    -- :bd is also the exact rhs of <leader>bD; the list says Space b d
    eq("<leader>bd", nudge.match("bd"))
    eq("<leader>bd", nudge.match("bdelete"))
  end)

  it("matches commands that are not installed", function()
    eq("<leader>ff", nudge.match("Telescope find_files"))
    eq("<leader>gg", nudge.match("LazyGit"))
    eq("<leader>e", nudge.match("Neotree toggle"))
    eq("<leader>/", nudge.match("Telescope live_grep"))
  end)

  it("matches the rhs of your text keymaps", function()
    eq("<Tab><Tab>", nudge.match("tabnew"))
    eq("<C-S>", nudge.match("w"))
    eq("<leader>bb", nudge.match("e #"))
  end)

  it("matches :set for toggles", function()
    eq("<leader>uw", nudge.match("set nowrap"))
    eq("<leader>uw", nudge.match("setlocal wrap!"))
    eq("<leader>ul", nudge.match("set nu"))
    eq(nil, nudge.match("set wrap?"))
  end)

  it("skips commands with a range, other args, quits and keys you do not have", function()
    eq(nil, nudge.match("%bd"))
    eq(nil, nudge.match("Gitsigns blame_line")) -- <leader>gb is not mapped in tests/init.lua
    eq(nil, nudge.match("qa"))
    eq(nil, nudge.match("Telescope oldfiles_typo"))
  end)
end)

describe("nudges", function()
  before_each(function()
    config.setup({ nudge = { every = 0 } })
    require("lazynator").start()
    close_hints()
  end)

  it("shows the key when you type the command", function()
    vim.cmd("edit one.txt")
    vim.cmd("edit two.txt")
    local before = progress.get("<leader>bd").nudges
    type_keys(":bd<CR>")
    eq(before + 1, progress.get("<leader>bd").nudges)
    truthy(wait_for(hint_text), "hint window")
    truthy(hint_text():find("Next time: [Space] [b] [d]", 1, true), hint_text())
    truthy(hint_text():find("You typed :bd", 1, true))
  end)

  it("does not nudge a command sent by a keymap", function()
    vim.keymap.set("n", "<leader>zt", ":tabnew<CR>")
    local got = nudged(function()
      type_keys("<leader>zt")
    end)
    eq({}, got)
    vim.cmd("tabclose")
    vim.keymap.del("n", "<leader>zt")
  end)

  it("shows the hint once per N minutes, but every slow way resets the streak", function()
    config.setup({ nudge = { every = 10 } })
    progress.press("<Tab><Tab>")
    type_keys(":tabnew<CR>")
    truthy(wait_for(hint_text))
    close_hints()
    progress.press("<Tab><Tab>")
    type_keys(":tabnew<CR>")
    vim.wait(100)
    eq(nil, hint_text())
    eq(0, progress.get("<Tab><Tab>").streak)
    vim.cmd("tabonly")
  end)

  it("can be turned off per key and fully", function()
    config.setup({ nudge = { every = 0, skip = { "<C-s>" } } })
    eq({}, nudged(function()
      nudge.nudge("<C-S>", "test")
    end))
    config.setup({ nudge = { enabled = false } })
    eq({}, nudged(function()
      nudge.nudge("<leader>bd", "test")
    end))
  end)
end)

describe("mouse", function()
  before_each(function()
    config.setup({ nudge = { every = 0 } })
  end)

  it("bufferline tab clicks: next/prev tab -> Shift l/h, far tab -> Space ,, close icon -> Space b d", function()
    vim.cmd("edit t1.txt | edit t2.txt | edit t3.txt | edit t1.txt")
    local b1, b2, b3 = vim.fn.bufnr("t1.txt"), vim.fn.bufnr("t2.txt"), vim.fn.bufnr("t3.txt")
    local closed
    _G.___bufferline_private = {
      handle_click = function(id)
        vim.api.nvim_set_current_buf(id)
      end,
      handle_close = function(id)
        closed = id
      end,
    }
    package.loaded.bufferline = {
      get_elements = function()
        return { elements = { { id = b1 }, { id = b2 }, { id = b3 } } }
      end,
    }
    nudge.hook_bufferline()
    nudge.hook_bufferline() -- hooking twice must not double up
    local p = _G.___bufferline_private
    eq({ "L" }, nudged(function()
      p.handle_click(b2, 1, "l", "")
    end))
    eq(b2, vim.api.nvim_get_current_buf())
    eq({ "H" }, nudged(function()
      p.handle_click(b1, 1, "l", "")
    end))
    eq({ "<leader>," }, nudged(function()
      p.handle_click(b3, 1, "l", "")
    end))
    eq({ "<leader>bd" }, nudged(function()
      p.handle_close(b2, 1, "l", "")
    end))
    eq(b2, closed)
    _G.___bufferline_private = nil
    package.loaded.bufferline = nil
  end)

  it("file tree: click into it -> Space e, double click opens a file -> Space Space", function()
    vim.cmd("only | edit file.txt")
    local file_win = vim.api.nvim_get_current_win()
    vim.cmd("topleft vsplit | enew")
    vim.bo.buftype = "nofile"
    vim.bo.filetype = "neo-tree"
    local tree = vim.api.nvim_get_current_win()
    local getmousepos = vim.fn.getmousepos
    vim.fn.getmousepos = function()
      return { winid = tree }
    end
    vim.api.nvim_set_current_win(file_win)
    eq({ "<leader>e" }, nudged(function()
      nudge.on_mouse("<LeftMouse>")
      vim.api.nvim_set_current_win(tree)
    end, vim.o.mousetime + 200))
    eq({ "<leader><Space>" }, nudged(function()
      nudge.on_mouse("<LeftMouse>")
      nudge.on_mouse("<2-LeftMouse>")
      vim.api.nvim_set_current_win(file_win) -- the tree opened the file
    end, 300))
    vim.fn.getmousepos = getmousepos
    vim.api.nvim_win_close(tree, true)
  end)
end)
