local ui = require("lazynator.ui")
local config = require("lazynator.config")

-- A fake snacks.nvim that "shows" pictures: records what would be sent to the terminal.
local sent, placed = {}, {}
local images = {}
local function fake_snacks(can_show)
  package.loaded.snacks = {
    image = {
      supports_terminal = function()
        return can_show
      end,
      setup = function() end,
      image = {
        new = function(file)
          images[file] = images[file] or {
            file = file,
            sent = false,
            ready = function()
              return true
            end,
          }
          return images[file]
        end,
      },
      placement = {
        new = function(buf, file, opts)
          local img = package.loaded.snacks.image.image.new(file)
          if not img.sent then
            img.sent = true
            sent[#sent + 1] = vim.fn.fnamemodify(file, ":t")
          end
          local p = { buf = buf, file = file, opts = opts }
          function p.close()
            p.closed = true
          end
          placed[#placed + 1] = p
          return p
        end,
      },
    },
  }
end

-- ui caches "can this terminal show pictures", so load it fresh for each case.
local function fresh_ui()
  package.loaded["lazynator.ui"] = nil
  ui = require("lazynator.ui")
  return ui
end

local function set_size(lines, columns)
  vim.o.lines, vim.o.columns = lines, columns
end

local function picture_win(f)
  return f.pic_win and vim.api.nvim_win_is_valid(f.pic_win) and f.pic_win or nil
end

describe("box size", function()
  it("follows the terminal: small, medium, large", function()
    set_size(25, 100)
    eq("small", ui.size())
    set_size(40, 100)
    eq("medium", ui.size())
    set_size(60, 150)
    eq("large", ui.size())
    set_size(60, 70) -- narrow is small, even when tall
    eq("small", ui.size())
  end)
end)

describe("Spacey", function()
  before_each(function()
    sent, placed, images = {}, {}, {}
    config.setup({})
    set_size(40, 120)
  end)

  it("is a text drawing when the terminal can not show pictures", function()
    fake_snacks(false)
    local lines = fresh_ui().with_spacey("idle", { { { "hi" } } })
    eq(nil, lines.picture)
    truthy(table.concat(vim.tbl_map(function(s)
      return s[1]
    end, lines[1])):find("━┯━━━┯━", 1, true))
  end)

  it("is a picture when it can, in every size, and the picture grows with the terminal", function()
    fake_snacks(true)
    fresh_ui()
    local got = {}
    for _, sz in ipairs({ { 25, 100 }, { 40, 120 }, { 60, 150 } }) do
      set_size(sz[1], sz[2])
      local lines = ui.with_spacey("idle", { { { "hi" } } })
      truthy(lines.picture and lines.picture:find("idle.png", 1, true), vim.inspect(lines.picture))
      got[#got + 1] = lines.pic_h
    end
    truthy(got[1] < got[2] and got[2] < got[3], vim.inspect(got))
  end)

  it("uses the pose for the mood", function()
    fake_snacks(true)
    fresh_ui()
    eq("think.png", vim.fn.fnamemodify(ui.with_spacey("think", {}).picture, ":t"))
    eq("success.png", vim.fn.fnamemodify(ui.with_spacey("happy", {}).picture, ":t"))
    eq("done.png", vim.fn.fnamemodify(ui.with_spacey("done", {}).picture, ":t"))
  end)

  it("mascot = 'text' always gives the text drawing", function()
    fake_snacks(true)
    config.setup({ mascot = "text" })
    eq(nil, fresh_ui().with_spacey("idle", {}).picture)
  end)

  it("sends the picture again after a resize (the terminal may drop it)", function()
    fake_snacks(true)
    fresh_ui()
    local f = {}
    local function draw()
      ui.show(f, { pos = "center", lines = ui.with_spacey("idle", { { { "hi" } } }), redraw = draw })
    end
    draw()
    truthy(picture_win(f), "picture window")
    eq({ "idle.png" }, sent)
    vim.api.nvim_exec_autocmds("VimResized", {})
    eq({ "idle.png", "idle.png" }, sent)
    truthy(picture_win(f), "picture window after resize")
    ui.close(f)
    eq(nil, picture_win(f))
  end)

  it("sends the picture again on a pose change back (snacks deletes it with the last placement)", function()
    fake_snacks(true)
    fresh_ui()
    local f = {}
    ui.show(f, { pos = "center", lines = ui.with_spacey("idle", {}) })
    ui.show(f, { pos = "center", lines = ui.with_spacey("happy", {}) })
    ui.show(f, { pos = "center", lines = ui.with_spacey("idle", {}) })
    eq({ "idle.png", "success.png", "idle.png" }, sent)
    ui.close(f)
  end)

  it("puts the picture over the blank space next to the text, and closes it with the box", function()
    fake_snacks(true)
    fresh_ui()
    local f = {}
    local lines = ui.with_spacey("idle", { { { "Hi!" } } })
    ui.show(f, { pos = "center", lines = lines })
    local pw = picture_win(f)
    local cfg = vim.api.nvim_win_get_config(pw)
    eq(f.win, cfg.win)
    eq(lines.pic_w, cfg.width)
    -- the text starts right of the picture
    local first = vim.api.nvim_buf_get_lines(f.buf, 0, 1, false)[1]
    truthy(first:find("Hi!", 1, true) > lines.pic_w, first)
    ui.close(f)
    eq(false, vim.api.nvim_win_is_valid(pw))
  end)
end)

-- leave a real-looking state for the other spec files
package.loaded.snacks = nil
package.loaded["lazynator.ui"] = nil
