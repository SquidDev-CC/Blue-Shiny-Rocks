# Blue Shiny rocks

Blue Shiny Rocks, or BSRocks for short serves two purposes:
 - Emulation of the Lua 5.1 environment
 - Lightweight implementation of [LuaRocks](https://luarocks.org/)

Most functionality of Lua 5.1 is implemented, with the following caveats:
 - The [debug library](http://www.lua.org/manual/5.1/manual.html#5.9) is only partially implemented:
   - `debug.traceback` does not accept threads
   - `debug.getinfo` only accepts a numeric value
   - `.getmetatable`, `.setmetatable`, `.getfenv` and `.setfenv` are just their normal versions
   - Everything else is not implemented
 - `os.setlocale` library is not implemented
 - `io.popen` is not implemented.
 - Several LuaJ bugs:
   - `\011` is not considered whitespace\*
   - `string.format` floating point specifiers don't work (e.g. `%5.2f`)
   - `string.gmatch` will infinitely loop on the `*` pattern (e.g. `\n*`)\*
   - `getmetatable` returns the string library for strings.
   - String's metatable and the `string` library are not the same, so you cannot add string methods.
   - `%b` errors when no match is found.\*

\* *Fixed in CC 1.79pr2 or CCTweaks 0.3.1*

The LuaRocks implementation is very minimal:
 - Currently only supports downloading GitHub repositories
 - Only pure Lua libraries are supported

## Getting started
 - First install from the Gist: `pastebin run LYAxmSby get 6ced21eb437a776444aacef4d597c0f7/bsrocks.min.lua bsrocks`
 - Look for a package: `bsrocks search colours`
 - Check it is the one you want: `bsrocks desc ansicolors`
 - Install it: `bsrocks install ansicolors`
 - Use it: `bsrocks repl` or `bsrocks exec myFile.lua`

You can also run `bsrocks help` for more information.

## Patchspec
The LuaRocks library also downloads "patchspec"s. These define modifications
required for a library to work in CC. The next big stage of this project is to
write ports and patches for key libraries.

The ultimate aim is to be able to run most pure Lua libraries with minimal, or no
patching. The repository for custom Lua ports and patchspecs is on a
[separate branch](https://github.com/SquidDev-CC/Blue-Shiny-Rocks/tree/rocks).
