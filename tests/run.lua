-- Tiny test runner: nvim --headless -u tests/init.lua -l tests/run.lua [spec files...]
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local files = _G.arg and #_G.arg > 0 and _G.arg or vim.fn.glob(root .. "/tests/*_spec.lua", false, true)
table.sort(files)

local passed, failed = 0, {}
local current = {}

function _G.describe(name, fn)
  current[#current + 1] = name
  fn()
  current[#current] = nil
end

local before = {}
function _G.before_each(fn)
  before[#current] = fn
end

function _G.it(name, fn)
  local full = table.concat(current, " > ") .. " > " .. name
  for i = 1, #current do
    if before[i] then
      before[i]()
    end
  end
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
    io.write("  ok   " .. full .. "\n")
  else
    failed[#failed + 1] = full .. "\n" .. tostring(err)
    io.write("  FAIL " .. full .. "\n")
  end
end

function _G.eq(want, got, msg)
  if not vim.deep_equal(want, got) then
    error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", vim.inspect(want), vim.inspect(got)), 2)
  end
end

function _G.truthy(v, msg)
  if not v then
    error((msg or "expected a true value") .. ", got " .. vim.inspect(v), 2)
  end
end

--- Wait until fn() is true (runs the event loop).
function _G.wait_for(fn, ms)
  return vim.wait(ms or 2000, fn, 10)
end

for _, f in ipairs(files) do
  io.write(vim.fn.fnamemodify(f, ":t") .. "\n")
  before = {}
  local ok, err = xpcall(dofile, debug.traceback, f)
  if not ok then
    failed[#failed + 1] = f .. "\n" .. tostring(err)
    io.write("  FAIL (load) " .. f .. "\n")
  end
end

io.write(("\n%d passed, %d failed\n"):format(passed, #failed))
for _, f in ipairs(failed) do
  io.write("\n" .. f .. "\n")
end
io.flush()
os.exit(#failed == 0 and 0 or 1)
