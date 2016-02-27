version = "2.5-2"
dependencies = {
  "lua >= 5.1, < 5.4",
}
build = {
  modules = {
    dkjson = "dkjson.lua",
  },
  type = "builtin",
}
description = {
  summary = "David Kolf's JSON module for Lua",
  detailed = "dkjson is a module for encoding and decoding JSON data. It supports UTF-8.\
\
JSON (JavaScript Object Notation) is a format for serializing data based\
on the syntax for JavaScript data structures.\
\
dkjson is written in Lua without any dependencies, but\
when LPeg is available dkjson uses it to speed up decoding.\
",
  homepage = "http://dkolf.de/src/dkjson-lua.fsl/",
  license = "MIT/X11",
}
source = {
  file = "dkjson.lua",
  single = "http://dkolf.de/src/dkjson-lua.fsl/raw/dkjson.lua?name=16cbc26080996d9da827df42cb0844a25518eeb3",
}
package = "dkjson"
