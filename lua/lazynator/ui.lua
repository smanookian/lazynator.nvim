-- Floating windows, keycaps and Spacey the sloth. Colors link to your colorscheme.
local M = {}

local keys = require("lazynator.keys")
local ns = vim.api.nvim_create_namespace("lazynator.ui")

local links = {
  LazynatorNormal = "NormalFloat",
  LazynatorBorder = "FloatBorder",
  LazynatorTitle = "FloatTitle",
  LazynatorDim = "Comment",
  LazynatorCap = "Pmenu",
  LazynatorCapLit = "IncSearch",
  LazynatorCapDone = "DiffAdd",
  LazynatorOk = "DiagnosticOk",
  LazynatorWarn = "DiagnosticWarn",
  LazynatorNew = "Comment",
  LazynatorLearning = "DiagnosticWarn",
  LazynatorLearned = "DiagnosticOk",
  LazynatorBar = "Comment",
}

function M.colors()
  for name, link in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  -- Spacey's colors: Neovim green body, one burnt-orange brand detail (same orange as Kappy).
  vim.api.nvim_set_hl(0, "LazynatorSpacey", { fg = "#57A143", default = true })
  vim.api.nvim_set_hl(0, "LazynatorAccent", { fg = "#C44D2B", bold = true, default = true })
end

local colors_set = false
local function ensure_colors()
  if colors_set then
    return
  end
  colors_set = true
  M.colors()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("lazynator.colors", { clear = true }),
    callback = M.colors,
  })
end

---@alias lazynator.Seg {[1]:string, [2]:string?}
---@alias lazynator.Line lazynator.Seg[]

local eyes = { idle = "- -", think = "◉ -", happy = "◉ ◉", done = "^ ^" }

--- Spacey: a robot sloth hanging from the space bar (sitting on it when a lesson is done).
---@return lazynator.Line[]
function M.spacey(mood)
  local S, A, B = "LazynatorSpacey", "LazynatorAccent", "LazynatorBar"
  local face = { { "│ ", S }, { eyes[mood] or eyes.idle, S }, { " │", S } }
  if mood == "done" then
    return {
      { { "╲  ", S }, { "✦", A }, { "  ╱", S } },
      { { "╭─────╮", S } },
      face,
      { { "━┷━", B }, { "●", A }, { "━┷━", B } },
    }
  end
  return {
    { { "━┯━━━┯━", B } },
    { { "╭┴───┴╮", S } },
    face,
    { { "╰──", S }, { "●", A }, { "──╯", S } },
  }
end

-- Sizes, picked from the terminal size (and picked again when you resize):
-- small: text drawing, compact. medium: picture 5 rows tall. large: picture 9 rows, more space.
local SIZES = {
  small = { pad_x = 1, pad_y = 0 },
  medium = { pad_x = 1, pad_y = 0, pic_w = 12, pic_h = 5 },
  large = { pad_x = 3, pad_y = 1, pic_w = 22, pic_h = 9 },
}

---@return "small"|"medium"|"large"
function M.size()
  local rows, cols = vim.o.lines, vim.o.columns
  if rows < 30 or cols < 80 then
    return "small"
  elseif rows < 50 or cols < 110 then
    return "medium"
  end
  return "large"
end

-- Picture mode: the real pixel Spacey, drawn by snacks.nvim in terminals with the kitty
-- graphics protocol (Ghostty, Kitty, WezTerm). Other terminals get the text drawing.
local root = debug.getinfo(1, "S").source:sub(2):match("^(.*)/lua/lazynator/ui%.lua$")
local pictures = { idle = "idle", think = "think", happy = "success", done = "done" }
local picture_ok ---@type boolean?

--- True when the terminal can show Spacey as a picture.
function M.picture()
  local want = require("lazynator.config").options.mascot
  if want == "text" then
    return false
  end
  if picture_ok == nil then
    local ok, supported = pcall(function()
      local Snacks = require("snacks")
      return Snacks.image ~= nil and Snacks.image.supports_terminal()
    end)
    picture_ok = ok and supported == true and root ~= nil
    if picture_ok then
      -- Load every pose now, so switching poses later is instant (the first load takes a moment).
      pcall(function()
        local Snacks = require("snacks")
        Snacks.image.setup()
        for _, name in pairs(pictures) do
          Snacks.image.image.new(root .. "/assets/spacey/" .. name .. ".png")
        end
      end)
    end
  end
  return picture_ok
end

--- Put Spacey on the left of some lines.
---@param mood string
---@param right lazynator.Line[]
---@return lazynator.Line[]
function M.with_spacey(mood, right)
  local s = SIZES[M.size()]
  local picture = s.pic_w ~= nil and M.picture()
  local art = picture and {} or M.spacey(mood)
  local w = picture and s.pic_w or 7
  local out = {}
  -- picture mode: one free row on top, then the picture rows (snacks draws from the 2nd row)
  for i = 1, math.max(picture and s.pic_h + 1 or #art, #right) do
    local line = vim.deepcopy(art[i] or { { string.rep(" ", w) } })
    line[#line + 1] = { "  " }
    vim.list_extend(line, right[i] or {})
    out[i] = line
  end
  if picture then
    out.picture = root .. "/assets/spacey/" .. (pictures[mood] or "idle") .. ".png"
    out.pic_w, out.pic_h = s.pic_w, s.pic_h
  end
  return out
end

local function close_picture(f)
  if f.placement then
    pcall(f.placement.close, f.placement)
    f.placement = nil
  end
  if f.pic_win and vim.api.nvim_win_is_valid(f.pic_win) then
    pcall(vim.api.nvim_win_close, f.pic_win, true)
  end
  if f.pic_buf and vim.api.nvim_buf_is_valid(f.pic_buf) then
    pcall(vim.api.nvim_buf_delete, f.pic_buf, { force = true })
  end
  f.pic_win, f.pic_buf, f.picture = nil, nil, nil
end

-- Counts terminal resizes. Ghostty forgets picture data when its window changes size, so a
-- picture shown before a resize must be sent again.
local resizes = 0

-- The picture gets its own small window on top of the blank area at the left of the float.
-- (snacks.nvim can not draw a picture next to text in one window without hiding that text.)
local function place_picture(f, lines, s)
  local file = lines.picture
  local key = file and (file .. lines.pic_w .. "x" .. lines.pic_h)
  if not file or (f.picture and (f.picture ~= key or f.pic_resizes ~= resizes)) then
    close_picture(f)
  end
  if not file then
    return
  end
  local cfg = {
    relative = "win",
    win = f.win,
    row = s.pad_y,
    col = s.pad_x,
    width = lines.pic_w,
    height = lines.pic_h + 1,
    style = "minimal",
    focusable = false,
    zindex = vim.api.nvim_win_get_config(f.win).zindex + 1,
  }
  if f.pic_win and vim.api.nvim_win_is_valid(f.pic_win) then
    vim.api.nvim_win_set_config(f.pic_win, cfg)
    return
  end
  close_picture(f)
  f.pic_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[f.pic_buf].bufhidden = "hide"
  cfg.noautocmd = true
  f.pic_win = vim.api.nvim_open_win(f.pic_buf, false, cfg)
  vim.wo[f.pic_win].winhighlight = "Normal:LazynatorNormal,NormalFloat:LazynatorNormal"
  f.picture = key
  f.pic_resizes = resizes
  local Snacks = require("snacks")
  -- Always send the picture data again (it is only a file path, so this is cheap). The terminal
  -- may have dropped it: after a resize, or when snacks deleted it with the last placement
  -- while still marking it as sent. Then the picture would stay blank.
  local img = Snacks.image.image.new(file)
  if img:ready() then
    img.sent = false
  end
  f.placement = Snacks.image.placement.new(f.pic_buf, file, { width = lines.pic_w, height = lines.pic_h })
end

--- Keycaps for a key: [Space] [b] [d]
---@param lit? integer how many caps are lit
---@param done? boolean
---@return lazynator.Line
function M.caps(id, lit, done)
  local segs = {}
  for i, l in ipairs(keys.labels(id)) do
    if i > 1 then
      segs[#segs + 1] = { " " }
    end
    local hl = done and "LazynatorCapDone" or (i <= (lit or 0) and "LazynatorCapLit" or "LazynatorCap")
    segs[#segs + 1] = { "[" .. l .. "]", hl }
  end
  return segs
end

local function width_of(line)
  local w = 0
  for _, s in ipairs(line) do
    w = w + vim.api.nvim_strwidth(s[1])
  end
  return w
end

--- Write lines with highlights into a buffer, with padding around them. Returns the widest line.
---@param lines lazynator.Line[]
function M.render(buf, lines, pad_x, pad_y)
  pad_x, pad_y = pad_x or 1, pad_y or 0
  local pad = string.rep(" ", pad_x)
  local text, marks, width = {}, {}, 0
  for _ = 1, pad_y do
    text[#text + 1] = ""
  end
  for _, segs in ipairs(lines) do
    local parts, col = { pad }, pad_x
    for _, s in ipairs(segs) do
      parts[#parts + 1] = s[1]
      if s[2] then
        marks[#marks + 1] = { #text, col, col + #s[1], s[2] }
      end
      col = col + #s[1]
    end
    text[#text + 1] = table.concat(parts) .. pad
    width = math.max(width, width_of(segs) + 2 * pad_x)
  end
  for _ = 1, pad_y do
    text[#text + 1] = ""
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
  return width, #text
end

---@class lazynator.Float
---@field buf? integer
---@field win? integer
---@field redraw? fun() draws the float again when the terminal is resized

---@class lazynator.FloatOpts
---@field lines lazynator.Line[]
---@field title? string
---@field pos "top"|"bottom"|"bottom_left"|"center"
---@field focus? boolean
---@field width? integer minimum width
---@field redraw? fun() how to draw it again after a resize (it may change size)

local open = setmetatable({}, { __mode = "k" }) ---@type table<lazynator.Float, true>

--- Open or update a float.
---@param f lazynator.Float
---@param o lazynator.FloatOpts
function M.show(f, o)
  ensure_colors()
  if not (f.buf and vim.api.nvim_buf_is_valid(f.buf)) then
    f.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[f.buf].bufhidden = "hide"
    vim.bo[f.buf].filetype = "lazynator"
    local buf = f.buf
    -- A buffer key pressed inside the menu (like Space b d or Space b b) puts another buffer
    -- into this window. Then the window is no longer ours: close it instead of showing junk.
    vim.api.nvim_create_autocmd("BufWinLeave", {
      buffer = buf,
      callback = function()
        vim.schedule(function()
          if f.buf == buf and f.win and vim.api.nvim_win_is_valid(f.win) and vim.api.nvim_win_get_buf(f.win) ~= buf then
            local other = vim.api.nvim_win_get_buf(f.win)
            M.close(f)
            -- "Delete buffer" may have made an empty [No Name] buffer just for this window.
            if vim.api.nvim_buf_is_valid(other) and vim.api.nvim_buf_get_name(other) == ""
              and not vim.bo[other].modified and #vim.fn.win_findbuf(other) == 0 then
              pcall(vim.api.nvim_buf_delete, other, {})
            end
          end
        end)
      end,
    })
  end
  local s = SIZES[M.size()]
  local text_width, height = M.render(f.buf, o.lines, s.pad_x, s.pad_y)
  local width = math.max(text_width, o.width or 0)
  local cols, rows = vim.o.columns, vim.o.lines
  local cfg = {
    relative = "editor",
    width = math.min(width, cols - 4),
    height = math.min(height, rows - 4),
    style = "minimal",
    border = "rounded",
    title = o.title and (" " .. o.title .. " ") or nil,
    title_pos = o.title and "center" or nil,
    focusable = o.focus == true,
    zindex = o.focus and 150 or 250,
  }
  local bottom = rows - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
  if o.pos == "top" then
    cfg.anchor, cfg.row, cfg.col = "NE", 1, cols - 1
  elseif o.pos == "bottom" then
    cfg.anchor, cfg.row, cfg.col = "SE", bottom, cols - 1
  elseif o.pos == "bottom_left" then
    cfg.anchor, cfg.row, cfg.col = "SW", bottom, 0
  else
    cfg.anchor = "NW"
    cfg.row = math.max(0, math.floor((rows - height) / 2) - 1)
    cfg.col = math.max(0, math.floor((cols - width) / 2))
  end
  local tab = vim.api.nvim_get_current_tabpage()
  if f.win and vim.api.nvim_win_is_valid(f.win) and vim.api.nvim_win_get_tabpage(f.win) == tab then
    vim.api.nvim_win_set_config(f.win, cfg)
  else
    M.close(f, true)
    cfg.noautocmd = true
    f.win = vim.api.nvim_open_win(f.buf, o.focus == true, cfg)
    vim.wo[f.win].winhighlight =
      "Normal:LazynatorNormal,NormalFloat:LazynatorNormal,FloatBorder:LazynatorBorder,FloatTitle:LazynatorTitle"
    vim.wo[f.win].wrap = false
  end
  f.redraw = o.redraw
  open[f] = true
  pcall(place_picture, f, o.lines, s)
  return s.pad_y
end

-- On resize, draw open floats again: the size (and the picture size) may change.
-- Draw right away (so the box fits), and once more when the resizing has stopped: Ghostty clears
-- pictures a moment after the resize, so the picture must be sent after that.
local function redraw_all()
  for f in pairs(open) do
    if f.redraw and f.win and vim.api.nvim_win_is_valid(f.win) then
      pcall(f.redraw)
    end
  end
end
local settle = (vim.uv or vim.loop).new_timer()
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("lazynator.resize", { clear = true }),
  callback = function()
    resizes = resizes + 1
    redraw_all()
    settle:stop()
    settle:start(250, 0, vim.schedule_wrap(function()
      resizes = resizes + 1
      redraw_all()
    end))
  end,
})

---@param f lazynator.Float
---@param keep_buf? boolean
function M.close(f, keep_buf)
  close_picture(f)
  if f.win and vim.api.nvim_win_is_valid(f.win) then
    pcall(vim.api.nvim_win_close, f.win, true)
  end
  f.win = nil
  if not keep_buf then
    if f.buf and vim.api.nvim_buf_is_valid(f.buf) then
      pcall(vim.api.nvim_buf_delete, f.buf, { force = true })
    end
    f.buf = nil
  end
end

--- A small bar: ■ learned, ▣ learning, □ new.
function M.bar(done, total, size, learning)
  size = size or 10
  local function part(x)
    return total > 0 and math.floor(x / total * size + 0.5) or 0
  end
  local n = part(done)
  local m = math.max(0, math.min(size - n, part(done + (learning or 0)) - n))
  if (learning or 0) > 0 and m == 0 and n < size then
    m = 1 -- show that you started, even for one key
  end
  return string.rep("■", n) .. string.rep("▣", m) .. string.rep("□", size - n - m)
end

return M
