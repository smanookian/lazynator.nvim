-- Lazynator: learn LazyVim keys inside your real Neovim.
-- setup() only stores options and waits; the real work starts after startup (VeryLazy).
local M = {}

local started = false

---@param opts? lazynator.Config
function M.setup(opts)
  require("lazynator.config").setup(opts)
  if vim.v.vim_did_enter == 1 then
    vim.schedule(M.start)
  else
    vim.api.nvim_create_autocmd(package.loaded.lazy and "User" or "VimEnter", {
      pattern = package.loaded.lazy and "VeryLazy" or "*",
      once = true,
      callback = function()
        -- after every other VeryLazy handler, so LazyVim's keymaps exist
        vim.schedule(M.start)
      end,
    })
  end
end

--- Start counting presses and showing nudges. Safe to call more than once.
function M.start()
  if started then
    return
  end
  started = true
  require("lazynator.track").start()
  require("lazynator.nudge").start()
  -- load Spacey's pictures in the background (only in terminals that can show them)
  vim.defer_fn(function()
    pcall(require("lazynator.ui").picture)
  end, 500)
end

return M
