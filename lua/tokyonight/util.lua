local M = {}

local uv = vim.uv or vim.loop

M.bg = "#000000"
M.fg = "#ffffff"
M.day_brightness = 0.3

---@param c  string
local function hexToRgb(c)
  c = string.lower(c)
  return { tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16) }
end

local me = debug.getinfo(1, "S").source:sub(2)
me = vim.fn.fnamemodify(me, ":h:h")

function M.mod(modname)
  return loadfile(me .. "/" .. modname:gsub("%.", "/") .. ".lua")()
end

---@param foreground string foreground color
---@param background string background color
---@param alpha number|string number between 0 and 1. 0 results in bg, 1 results in fg
function M.blend(foreground, background, alpha)
  alpha = type(alpha) == "string" and (tonumber(alpha, 16) / 0xff) or alpha
  local bg = hexToRgb(background)
  local fg = hexToRgb(foreground)

  local blendChannel = function(i)
    local ret = (alpha * fg[i] + ((1 - alpha) * bg[i]))
    return math.floor(math.min(math.max(0, ret), 255) + 0.5)
  end

  return string.format("#%02x%02x%02x", blendChannel(1), blendChannel(2), blendChannel(3))
end

function M.darken(hex, amount, bg)
  return M.blend(hex, bg or M.bg, amount)
end

function M.lighten(hex, amount, fg)
  return M.blend(hex, fg or M.fg, amount)
end

function M.invert_color(color)
  local hsluv = require("tokyonight.hsluv")
  if color ~= "NONE" then
    local hsl = hsluv.hex_to_hsluv(color)
    hsl[3] = 100 - hsl[3]
    if hsl[3] < 40 then
      hsl[3] = hsl[3] + (100 - hsl[3]) * M.day_brightness
    end
    return hsluv.hsluv_to_hex(hsl)
  end
  return color
end

---@param hl tokyonight.Highlight
---@param group string
function M.highlight(group, hl)
  if type(hl.style) == "table" then
    for k, v in pairs(hl.style) do
      hl[k] = v
    end
    hl.style = nil
  end
  vim.api.nvim_set_hl(0, group, hl)
end

---@param groups tokyonight.Highlights
---@return table<string, vim.api.keyset.highlight>
function M.resolve(groups)
  for _, hl in pairs(groups) do
    if type(hl.style) == "table" then
      for k, v in pairs(hl.style) do
        hl[k] = v
      end
      hl.style = nil
    end
  end
  return groups
end

-- Simple string interpolation.
--
-- Example template: "${name} is ${value}"
--
---@param str string template string
---@param table table key value pairs to replace in the string
function M.template(str, table)
  return (
    str:gsub("($%b{})", function(w)
      return vim.tbl_get(table, unpack(vim.split(w:sub(3, -2), ".", { plain = true }))) or w
    end)
  )
end

---@param colors ColorScheme
function M.invert_colors(colors)
  if type(colors) == "string" then
    ---@diagnostic disable-next-line: return-type-mismatch
    return M.invert_color(colors)
  end
  for key, value in pairs(colors) do
    colors[key] = M.invert_colors(value)
  end
  return colors
end

---@param hls Highlights
function M.invert_highlights(hls)
  for _, hl in pairs(hls) do
    if hl.fg then
      hl.fg = M.invert_color(hl.fg)
    end
    if hl.bg then
      hl.bg = M.invert_color(hl.bg)
    end
    if hl.sp then
      hl.sp = M.invert_color(hl.sp)
    end
  end
end

---@param key string
function M.cache_read(key)
  local cache_file = vim.fn.stdpath("cache") .. "/tokyonight-" .. key .. ".lua"
  ---@type boolean, tokyonight.Cache
  local ok, cache = pcall(function()
    local f = uv.fs_open(cache_file, "r", 438)
    if f then
      local stat = assert(uv.fs_fstat(f))
      local data = uv.fs_read(f, stat.size, 0) --[[@as string?]]
      uv.fs_close(f)
      return data and loadstring(data, "tokyonight")()
    end
  end)
  return ok and cache or nil
end

---@param key string
---@param cache tokyonight.Cache
function M.cache_write(key, cache)
  local code = "return " .. vim.inspect(vim.deepcopy(cache, true))
  local ok, chunk = pcall(loadstring, code, "tokyonight")
  if not (ok and chunk) then
    return
  end
  local cache_file = vim.fn.stdpath("cache") .. "/tokyonight-" .. key .. ".lua"
  local f = vim.uv.fs_open(cache_file, "w", 438)
  if f then
    -- selene: allow(incorrect_standard_library_use)
    uv.fs_write(f, string.dump(chunk, true))
    uv.fs_close(f)
  end
end

return M
