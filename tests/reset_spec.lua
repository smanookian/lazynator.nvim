local commands = require("lazynator.commands")
local progress = require("lazynator.progress")

local function with_answer(answer, fn)
  local confirm = vim.fn.confirm
  vim.fn.confirm = function()
    return answer
  end
  local ok, err = pcall(fn)
  vim.fn.confirm = confirm
  assert(ok, err)
end

local function fill()
  progress.reset()
  progress.press("<leader>bd") -- buffers
  progress.press("L") -- buffers
  progress.press("<leader>ff") -- files
  progress.nudge("<C-S>") -- other
end

describe(":Lazynator reset", function()
  it("does nothing when you answer No", function()
    fill()
    with_answer(2, function()
      commands.run({ "reset" })
    end)
    eq(1, progress.get("<leader>bd").presses)
  end)

  it("resets everything, also on disk", function()
    fill()
    with_answer(1, function()
      commands.run({ "reset" })
    end)
    eq("new", progress.state("<leader>bd"))
    eq("new", progress.state("<C-S>"))
    progress.reload()
    eq({}, vim.tbl_keys(progress.all()))
  end)

  it("resets only one group", function()
    fill()
    with_answer(1, function()
      commands.run({ "reset", "buffers" })
    end)
    eq("new", progress.state("<leader>bd"))
    eq("new", progress.state("L"))
    eq(1, progress.get("<leader>ff").presses)
    eq(1, progress.get("<C-S>").nudges)
    progress.reload()
    eq(1, progress.get("<leader>ff").presses)
    eq("new", progress.state("L"))
  end)

  it("keeps progress made after a reset", function()
    fill()
    with_answer(1, function()
      commands.run({ "reset" })
    end)
    progress.press("<leader>e")
    progress.save()
    progress.reload()
    eq(1, progress.get("<leader>e").presses)
  end)

  it("completes group names", function()
    eq({ "buffers" }, commands.complete("bu", "Lazynator reset bu"))
  end)
end)
