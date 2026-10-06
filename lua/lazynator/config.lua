local M = {}

---@class lazynator.Config
local defaults = {
  -- Spacey as a picture ("auto": when the terminal can draw images, like Ghostty or Kitty)
  -- or always as a small text drawing ("text").
  mascot = "auto",
  -- A key is learned after this many real presses in a row with no nudge.
  learned_after = 5,
  nudge = {
    enabled = true,
    -- Show the hint for the same key at most once every N minutes.
    every = 10,
    -- How long the hint stays, in ms.
    timeout = 8000,
    -- Keys that never get a hint, e.g. { "<C-s>", "<leader>bd" }.
    skip = {},
    -- Hints for mouse clicks on buffer tabs and the file tree.
    mouse = true,
  },
}

---@type lazynator.Config
M.options = vim.deepcopy(defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

return M
