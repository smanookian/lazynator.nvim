if vim.g.loaded_lazynator then
  return
end
vim.g.loaded_lazynator = true

vim.api.nvim_create_user_command("Lazynator", function(o)
  require("lazynator.commands").run(o.fargs)
end, {
  nargs = "*",
  desc = "Lazynator: learn LazyVim keys",
  complete = function(lead, line)
    return require("lazynator.commands").complete(lead, line)
  end,
})
