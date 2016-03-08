# Blue Shiny Rocks: Rocks repository

This is the rocks repository for Blue Shiny Rocks.
The main branch can be [found here](https://github.com/SquidDev-CC/Blue-Shiny-Rocks).
This stores patches and rewrites of Lua libraries for BSRocks.

## Getting started
 - Install Blue-Shiny-Rocks: [see here](https://github.com/SquidDev-CC/Blue-Shiny-Rocks#patchspec) on how to do that.
 - You'll need to create a patch directory (`/rocks-patch`) for the admin commands to become available. The easiest way is to clone the repository:
   - `mkdir rocks-patch && cd rocks-patch`
   - `git clone https://github.com/SquidDev-CC/Blue-Shiny-Rocks.git rocks`
   - `git checkout rocks`
 - Add a patch target: `bsrocks add-patchspec <package>`
 - Fetch the sources: `bsrocks fetch <package>`
 - Copy the sources: `bsrocks apply-patches <package>`
 - Start changing things!
 - Rebuild the patches: `bsrocks make-patches <package>`
 - Send a pull request!

## Targets
The short term goals is to port several major packages.

 - [x] [LuaFileSystem](https://keplerproject.github.io/luafilesystem/)
 - [x] [Penlight](https://github.com/stevedonovan/Penlight)
 - [x] [Busted](https://github.com/Olivine-Labs/busted)
 - [x] [LDoc](https://github.com/stevedonovan/LDoc)

Ideally any pure-lua package could be run on a CC computer.
