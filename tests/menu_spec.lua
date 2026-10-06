local menu = require("lazynator.menu")

local function float_text()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype == "lazynator" then
      return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
    end
  end
end

local function press(k)
  vim.api.nvim_feedkeys(vim.keycode(k), "mtx", false)
end

describe("menu", function()
  it("s opens the stats and they stay open", function()
    menu.open()
    truthy(float_text():find("Pick a lesson", 1, true))
    press("s")
    vim.wait(200)
    local t = float_text()
    truthy(t and t:find("Your progress", 1, true), t)
    press("q")
    eq(nil, float_text())
  end)

  it("after a lesson it opens with the next lesson selected", function()
    menu.open({ select = 2 })
    local t = float_text()
    truthy(t:find("Next: Files. Press Enter.", 1, true), t)
    local row = vim.api.nvim_get_current_line()
    truthy(row:find("Files", 1, true), row)
    press("q")
  end)
  it("closes, not breaks, when a buffer key puts another buffer in the menu window", function()
    vim.cmd("edit mine.txt")
    menu.open()
    vim.cmd("enew") -- what Space b d / Space b b do inside the menu
    vim.wait(100)
    eq(nil, float_text())
    eq({}, vim.tbl_filter(function(w)
      return vim.api.nvim_win_get_config(w).relative ~= ""
    end, vim.api.nvim_list_wins()))
    eq(0, #vim.tbl_filter(function(b)
      return vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) == ""
    end, vim.api.nvim_list_bufs()))
  end)
end)
