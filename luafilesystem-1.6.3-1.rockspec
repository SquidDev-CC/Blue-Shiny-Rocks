version = "1.6.3-1"
dependencies = {
  "lua >= 5.1",
  "computercraft >= 1.0",
}
build = {
  modules = {
    lfs = "lib/lfs.lua",
  },
  type = "builtin",
}
description = {
  summary = "File System Library for the Lua Programming Language",
  license = "MIT/X11",
  detailed = "      LuaFileSystem is a Lua library developed to complement the set of\
      functions related to file systems offered by the standard Lua\
      distribution. LuaFileSystem offers a portable way to access the\
      underlying directory structure and file attributes.\
   ",
}
source = {
  url = "git://github.com/SquidDev-CC/Blue-Shiny-Rocks",
  branch = "rocks"
}
package = "LuaFileSystem"
