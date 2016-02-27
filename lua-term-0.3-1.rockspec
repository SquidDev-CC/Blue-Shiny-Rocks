version = "0.3-1"
build = {
  modules = {
    [ "term.cursor" ] = "lib/term/cursor.lua",
    [ "term.colors" ] = "lib/term/colors.lua",
    [ "term.core" ] = "lib/term/core.lua",
    term = "lib/term/init.lua",
  },
  type = "builtin",
}
description = {
  homepage = "https://github.com/hoelzro/lua-term",
  summary = "Terminal functions for Lua",
  license = "MIT/X11",
}
source = {
  url = "git://github.com/SquidDev-CC/Blue-Shiny-Rocks",
  branch = "rocks"
}
package = "lua-term"
