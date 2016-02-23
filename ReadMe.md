# Blue Shiny rocks

Blue Shiny Rocks, or BSRocks for short serves two purposes:
 - Emulation of the Lua 5.1 environment
 - Lightweight implementation of [LuaRocks](https://luarocks.org/)

Most functionality of Lua 5.1 is implemented, with the following caveats:
 - The [debug library](http://www.lua.org/manual/5.1/manual.html#5.9) is only partially implemented.
   - `debug.traceback` does not accept threads
   - `debug.getinfo` only accepts a numeric value
   - `.getmetatable`, `.setmetatable`, `.getfenv` and `.setfenv` are just their normal versions
   - Everything else is not implemented
 - `string.gmatch` will infinitely loop on the `*` pattern (e.g. `\n*`)
 - `os` library is only partially implemented

The LuaRocks implementation is very minimal:
 - Currently only supports downloading GitHub repositories
 - Only pure Lua libraries are supported

## Patchspec
The LuaRocks library also downloads "patchspec"s. These define modifications
required for a library to work in CC. The next big stage of this project is to
write ports and patches for key libraries:
 - [LuaFileSystem](https://keplerproject.github.io/luafilesystem/)
 - [Penlight](https://github.com/stevedonovan/Penlight)

The ultimate aim is to be able to run most pure Lua libraries with minimal, or no
patching. The repository for custom Lua ports and patchspecs is on a
[separate branch](https://github.com/SquidDev-CC/Blue-Shiny-Rocks/tree/rocks).
