-- Minimal Neovim for tests: this plugin plus keymaps shaped like LazyVim's on Omarchy
-- (Lua callbacks for most keys, <Cmd> text for a few).
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
vim.g.mapleader = " "
vim.o.hidden = true

local map = vim.keymap.set
-- buffers
map("n", "<S-l>", "<Cmd>bnext<CR>", { desc = "Next Buffer" })
map("n", "<S-h>", "<Cmd>bprevious<CR>", { desc = "Prev Buffer" })
map("n", "<leader>bd", function()
  vim.cmd("bdelete")
end, { desc = "Delete Buffer" })
map("n", "<leader>bD", "<Cmd>:bd<CR>", { desc = "Delete Buffer and Window" })
map("n", "<leader>bb", "<Cmd>e #<CR>", { desc = "Switch to Other Buffer" })
map("n", "<leader>bo", function()
  -- like Snacks.bufdelete.other(): windows keep showing a buffer
  local cur = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= cur and vim.bo[b].buflisted then
      for _, w in ipairs(vim.fn.win_findbuf(b)) do
        vim.api.nvim_win_set_buf(w, cur)
      end
      vim.cmd("bdelete " .. b)
    end
  end
end, { desc = "Delete Other Buffers" })
map("n", "<leader>,", function() end, { desc = "Buffers" })
-- files
map("n", "<leader><space>", function() end, { desc = "Find Files (Root Dir)" })
map("n", "<leader>e", function() end, { desc = "Explorer NeoTree (Root Dir)" })
map("n", "<leader>ff", function() end, { desc = "Find Files (Root Dir)" })
map("n", "<leader>fr", function() end, { desc = "Recent" })
map("n", "<leader>fn", "<Cmd>enew<CR>", { desc = "New File" })
-- search
map("n", "<leader>/", function() end, { desc = "Grep (Root Dir)" })
map("n", "<leader>sg", function() end, { desc = "Grep (Root Dir)" })
map("n", "<leader>sk", function() end, { desc = "Keymaps" })
-- git
map("n", "<leader>gg", function() end, { desc = "Lazygit (Root Dir)" })
map("n", "<leader>gs", function() end, { desc = "Git Status" })
map("n", "<leader>gl", function() end, { desc = "Git Log" })
map("n", "<leader>gB", function() end, { desc = "Git Browse (open)" })
-- code
map("n", "<leader>cf", function() end, { desc = "Format" })
map("n", "<leader>cd", function() end, { desc = "Line Diagnostics" })
map("n", "<leader>cm", function() end, { desc = "Mason" })
-- toggles
map("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle Wrap" })
map("n", "<leader>ul", function()
  vim.wo.number = not vim.wo.number
end, { desc = "Toggle Line Numbers" })
map("n", "<leader>us", function()
  vim.wo.spell = not vim.wo.spell
end, { desc = "Toggle Spelling" })
-- windows
map("n", "<leader>-", "<C-W>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split Window Right", remap = true })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete Window", remap = true })
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })
-- other
map("n", "<Tab><Tab>", "<Cmd>tabnew<CR>", { desc = "New Tab" })
map("n", "<C-s>", "<Cmd>w<CR><Esc>", { desc = "Save File" })
