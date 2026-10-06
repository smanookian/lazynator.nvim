local progress = require("lazynator.progress")
local track = require("lazynator.track")

--- Type keys like a person (typed, remapped, run now).
local function type_keys(s)
  vim.api.nvim_feedkeys(vim.keycode(s), "mtx", false)
end

local function presses(id)
  return progress.get(id).presses
end

describe("real presses", function()
  before_each(function()
    require("lazynator").start()
    track.refresh()
  end)

  it("counts a Lua keymap and still runs it", function()
    vim.cmd("edit one.txt")
    vim.cmd("edit two.txt")
    local buf = vim.api.nvim_get_current_buf()
    local before = presses("<leader>bd")
    type_keys("<leader>bd")
    eq(before + 1, presses("<leader>bd"))
    eq(false, vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted)
  end)

  it("counts a text keymap and still runs it", function()
    local wins = #vim.api.nvim_tabpage_list_wins(0)
    local before = presses("<leader>-")
    type_keys("<leader>-")
    eq(before + 1, presses("<leader>-"))
    eq(wins + 1, #vim.api.nvim_tabpage_list_wins(0))
    type_keys("<leader>wd")
    eq(wins, #vim.api.nvim_tabpage_list_wins(0))
  end)

  it("does not count the same action done with a : command", function()
    local before = presses("<leader>-")
    type_keys(":split<CR>")
    eq(before, presses("<leader>-"))
    vim.cmd("close")
  end)

  it("counts a keymap you change at runtime after a refresh", function()
    local ran = false
    vim.keymap.set("n", "<leader>ff", function()
      ran = true
    end, { desc = "My Find Files" })
    track.refresh()
    local before = presses("<leader>ff")
    type_keys("<leader>ff")
    eq(true, ran)
    eq(before + 1, presses("<leader>ff"))
  end)

  it("wraps each keymap once", function()
    track.refresh()
    eq(0, track.refresh())
    local before = presses("<leader>ff")
    type_keys("<leader>ff")
    eq(before + 1, presses("<leader>ff"))
  end)

  it("counts buffer-local keymaps", function()
    local buf = vim.api.nvim_get_current_buf()
    vim.keymap.set("n", "<leader>ca", function() end, { buffer = buf, desc = "Code Action" })
    track.refresh(buf, true)
    local before = presses("<leader>ca")
    type_keys("<leader>ca")
    eq(before + 1, presses("<leader>ca"))
    vim.keymap.del("n", "<leader>ca", { buffer = buf })
  end)

  it("counts once when lazy.nvim replays the keys after loading a plugin", function()
    -- a stub like lazy.nvim's: on first press it sets the real keymap and feeds the keys again
    local real = 0
    vim.keymap.set("n", "<leader>sk", function()
      vim.keymap.set("n", "<leader>sk", function()
        real = real + 1
      end, { desc = "Keymaps" })
      track.refresh()
      vim.api.nvim_feedkeys(vim.keycode("<leader>sk"), "im", false)
    end, { desc = "Keymaps" })
    track.refresh()
    local before = presses("<leader>sk")
    type_keys("<leader>sk")
    eq(1, real)
    eq(before + 1, presses("<leader>sk"))
    type_keys("<leader>sk")
    eq(2, real)
    eq(before + 2, presses("<leader>sk"))
  end)

  it("tells listeners which key fired", function()
    local got
    local off = track.on_press(function(id)
      got = id
    end)
    type_keys("<leader>uw")
    off()
    eq("<leader>uw", got)
    type_keys("<leader>uw")
  end)
end)
