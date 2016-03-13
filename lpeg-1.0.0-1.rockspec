version = "1.0.0-1"
dependencies = {
  "lua >= 5.1",
}
build = {
  modules = {
    lpeg = "lib/lpeg.lua",
    re = "lib/re.lua",
  },
  type = "builtin",
}
description = {
  summary = "Parsing Expression Grammars For Lua",
  homepage = "http://www.inf.puc-rio.br/~roberto/lpeg.html",
  maintainer = "Gary V. Vaughan <gary@vaughan.pe>",
  license = "MIT/X11",
  detailed = "      LPeg is a new pattern-matching library for Lua, based on Parsing\
      Expression Grammars (PEGs). The nice thing about PEGs is that it\
      has a formal basis (instead of being an ad-hoc set of features),\
      allows an efficient and simple implementation, and does most things\
      we expect from a pattern-matching library (and more, as we can\
      define entire grammars).\
   ",
}
source = {
  url = "git://github.com/SquidDev-CC/Blue-Shiny-Rocks",
  branch = "rocks"
}
package = "LPeg"
