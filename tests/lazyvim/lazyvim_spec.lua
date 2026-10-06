-- Runs inside a real LazyVim (see scripts/test-lazyvim.sh). Checks Lazynator against LazyVim's own keymaps.
local keys = require("lazynator.keys")
local groups = require("lazynator.groups")
local nudge = require("lazynator.nudge")
local progress = require("lazynator.progress")

-- Headless has no UI, so start what a UI start would (VeryLazy loads LazyVim's keymaps).
vim.api.nvim_exec_autocmds("UIEnter", {})
truthy(wait_for(function()
  return package.loaded["lazynator.track"] ~= nil and keys.live()["<leader>bd"] ~= nil
end, 10000), "LazyVim and Lazynator started")
vim.wait(300)

describe("LazyVim", function()
  it("has at least 3 keys in each of the 7 groups", function()
    local live = keys.live()
    for _, g in ipairs(groups.list) do
      local n = #keys.group_keys(g, live)
      truthy(n >= 3, g.id .. " has " .. n .. " keys")
    end
  end)

  it("nudges :bd, :Neotree, :Telescope find_files and :LazyGit to the right keys", function()
    eq("<leader>bd", nudge.match("bd"))
    eq("<leader>e", nudge.match("Neotree"))
    eq("<leader>ff", nudge.match("Telescope find_files"))
    -- LazyVim only maps Space g g when the lazygit program is installed (Omarchy has it).
    eq(vim.fn.executable("lazygit") == 1 and "<leader>gg" or nil, nudge.match("LazyGit"))
  end)

  it("counts a real press of a LazyVim keymap and the keymap still works", function()
    vim.cmd("edit one.txt | edit two.txt")
    local buf = vim.api.nvim_get_current_buf()
    local before = progress.get("<leader>bd").presses
    vim.api.nvim_feedkeys(vim.keycode("<leader>bd"), "mtx", false)
    truthy(wait_for(function()
      return progress.get("<leader>bd").presses == before + 1
    end), "press counted")
    truthy(wait_for(function()
      return not vim.bo[buf].buflisted
    end), "buffer deleted")
  end)

  it("does not count typing the command", function()
    vim.cmd("edit three.txt")
    local before = progress.get("<leader>bd").presses
    local nudges = progress.get("<leader>bd").nudges
    vim.api.nvim_feedkeys(":bd\r", "tx", false)
    eq(before, progress.get("<leader>bd").presses)
    eq(nudges + 1, progress.get("<leader>bd").nudges)
  end)
end)
