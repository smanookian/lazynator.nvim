-- The only built-in key list. It gives lesson order and groups.
-- Keys are read live from your config; a key listed here but missing there is skipped,
-- and keys under a group prefix that are not listed here are added after the listed ones.
local M = {}

-- setup: what a lesson prepares first ("buffers", "windows", "toggles", "project").
-- needs: what a single key needs right before it is asked ("split" = two windows).
-- ignore: keys under the prefix that are left out (they go online).
M.list = {
  {
    id = "buffers",
    name = "Buffers",
    prefix = "b",
    setup = "buffers",
    keys = {
      "<S-l>", "<S-h>", "<leader>bd", "<leader>,", "<leader>bb",
      "<leader>bo", "<leader>bj", "<leader>bp", "<leader>bP", "<leader>br",
      "<leader>bl", "<leader>bD", "]b", "[b", "<leader>`",
    },
  },
  {
    id = "files",
    name = "Files",
    prefix = "f",
    setup = "project",
    keys = {
      "<leader><space>", "<leader>e", "<leader>fr", "<leader>fn", "<leader>ft",
      "<leader>ff", "<leader>fb", "<leader>fc", "<leader>fe", "<leader>fg", "<C-/>",
    },
  },
  {
    id = "search",
    name = "Search",
    prefix = "s",
    setup = "project",
    keys = {
      "<leader>/", "<leader>sg", "<leader>sw", "<leader>sb", "<leader>sk",
      "<leader>sh", "<leader>sr", "<leader>sR", "<leader>sd", '<leader>s"',
      "<leader>:", "<leader>sc", "<leader>sC", "<leader>sm", "<leader>sj",
    },
  },
  {
    id = "git",
    name = "Git",
    prefix = "g",
    setup = "project",
    keys = {
      "<leader>gg", "<leader>gs", "<leader>gl", "<leader>gb", "<leader>gf",
      "<leader>gd", "<leader>gL", "<leader>gG", "<leader>gS",
    },
    ignore = { "<leader>gB", "<leader>gY", "<leader>gi", "<leader>gI", "<leader>gp", "<leader>gP" },
  },
  {
    id = "code",
    name = "Code",
    prefix = "c",
    setup = "project",
    file = "src/hello.lua",
    lsp = true,
    keys = {
      "<leader>cf", "<leader>cd", "<leader>ca", "<leader>cr", "<leader>cs",
      "<leader>cl", "<leader>cm", "<leader>cS", "<leader>cF", "gd", "gr",
    },
  },
  {
    id = "toggles",
    name = "Toggles",
    prefix = "u",
    setup = "toggles",
    keys = {
      "<leader>uw", "<leader>ul", "<leader>uL", "<leader>us", "<leader>ud",
      "<leader>uz", "<leader>uZ", "<leader>uc", "<leader>ug", "<leader>uh",
      "<leader>ub", "<leader>uC", "<leader>uf", "<leader>un", "<leader>ur",
    },
  },
  {
    id = "windows",
    name = "Windows",
    prefix = "w",
    setup = "windows",
    keys = {
      "<leader>|", { "<C-h>", needs = "split" }, { "<C-l>", needs = "split" }, "<leader>-",
      { "<C-k>", needs = "split" }, { "<C-j>", needs = "split" }, { "<leader>wd", needs = "split" },
      { "<leader>wm", needs = "split" }, { "<C-Up>", needs = "split" }, { "<C-Down>", needs = "split" },
      { "<C-Left>", needs = "split" }, { "<C-Right>", needs = "split" },
    },
  },
}

-- Slow ways: a typed command and the key to use instead.
-- args: nil = no args, "*" = any args, "+" = at least one arg, other = exact args.
-- Commands are also matched against the right-hand side of your text keymaps; this list wins.
M.slow = {
  { cmd = "bdelete", key = "<leader>bd" },
  { cmd = "bwipeout", key = "<leader>bd" },
  { cmd = "bnext", key = { "<S-l>", "]b" } },
  { cmd = "bprevious", key = { "<S-h>", "[b" } },
  { cmd = "bNext", key = { "<S-h>", "[b" } },
  { cmd = "buffers", key = "<leader>," },
  { cmd = "ls", key = "<leader>," },
  { cmd = "files", key = "<leader>," },
  { cmd = "BufferLineCloseOthers", key = "<leader>bo" },
  { cmd = "Neotree", args = "*", key = { "<leader>e", "<leader>fe" } },
  { cmd = "Explore", args = "*", key = "<leader>e" },
  { cmd = "edit", args = ".", key = "<leader>e" },
  { cmd = "edit", args = "+", key = "<leader>ff" },
  { cmd = "Telescope", args = "find_files", key = "<leader>ff" },
  { cmd = "Telescope", args = "git_files", key = { "<leader>fg", "<leader>ff" } },
  { cmd = "Telescope", args = "oldfiles", key = "<leader>fr" },
  { cmd = "Telescope", args = "buffers", key = "<leader>," },
  { cmd = "Telescope", args = "live_grep", key = "<leader>/" },
  { cmd = "Telescope", args = "grep_string", key = "<leader>sw" },
  { cmd = "Telescope", args = "current_buffer_fuzzy_find", key = "<leader>sb" },
  { cmd = "Telescope", args = "help_tags", key = "<leader>sh" },
  { cmd = "Telescope", args = "keymaps", key = "<leader>sk" },
  { cmd = "Telescope", args = "commands", key = "<leader>sC" },
  { cmd = "Telescope", args = "diagnostics", key = "<leader>sD" },
  { cmd = "Telescope", args = "resume", key = "<leader>sR" },
  { cmd = "Telescope", args = "colorscheme", key = "<leader>uC" },
  { cmd = "Telescope", args = "git_status", key = "<leader>gs" },
  { cmd = "Telescope", args = "git_commits", key = "<leader>gl" },
  { cmd = "FzfLua", args = "files", key = "<leader>ff" },
  { cmd = "FzfLua", args = "live_grep", key = "<leader>/" },
  { cmd = "FzfLua", args = "buffers", key = "<leader>," },
  { cmd = "grep", args = "*", key = "<leader>/" },
  { cmd = "vimgrep", args = "*", key = "<leader>/" },
  { cmd = "LazyGit", args = "*", key = "<leader>gg" },
  { cmd = "terminal", args = "lazygit", key = "<leader>gg" },
  { cmd = "Gitsigns", args = "blame_line", key = "<leader>gb" },
  { cmd = "Mason", key = "<leader>cm" },
  { cmd = "LspInfo", key = "<leader>cl" },
  { cmd = "LazyFormat", key = "<leader>cf" },
  { cmd = "Format", key = "<leader>cf" },
  { cmd = "lua", args = "vim.lsp.buf.format()", key = "<leader>cf" },
  { cmd = "lua", args = "vim.lsp.buf.code_action()", key = "<leader>ca" },
  { cmd = "lua", args = "vim.lsp.buf.rename()", key = "<leader>cr" },
  { cmd = "lua", args = "vim.diagnostic.open_float()", key = "<leader>cd" },
  { cmd = "split", key = "<leader>-" },
  { cmd = "new", key = "<leader>-" },
  { cmd = "vsplit", key = "<leader>|" },
  { cmd = "vnew", key = "<leader>|" },
  { cmd = "close", key = "<leader>wd" },
  { cmd = "colorscheme", args = "*", key = "<leader>uC" },
  { cmd = "nohlsearch", key = "<Esc>" },
  { set = { "wrap" }, key = "<leader>uw" },
  { set = { "number", "nu" }, key = "<leader>ul" },
  { set = { "relativenumber", "rnu" }, key = "<leader>uL" },
  { set = { "spell" }, key = "<leader>us" },
  { set = { "background", "bg" }, key = "<leader>ub" },
  { set = { "conceallevel", "cole" }, key = "<leader>uc" },
}

-- Commands that quit Neovim; a hint there is never seen.
M.quit = {
  quit = true, qall = true, quitall = true, wq = true, wqall = true,
  xit = true, xall = true, exit = true, cquit = true,
}

-- Mouse clicks and the keys to use instead (first one found in your config wins).
M.mouse = {
  tab_next = { "<S-l>", "]b" },
  tab_prev = { "<S-h>", "[b" },
  tab_other = { "<leader>,", "<leader>fb" },
  tab_close = { "<leader>bd" },
  tree = { "<leader>e", "<leader>fe" },
  tree_open = { "<leader><space>", "<leader>ff" },
}

---@return table?
function M.get(id)
  for _, g in ipairs(M.list) do
    if g.id == id then
      return g
    end
  end
end

return M
