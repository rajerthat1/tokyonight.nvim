local Util = require("tokyonight.util")

local M = {}

---@type tokyonight.HighlightsFn
function M.get(c)
  -- stylua: ignore
  return {
    TreesitterContext = { bg = Util.darken(c.fg_gutter, 0.8) },
  }
end

return M
