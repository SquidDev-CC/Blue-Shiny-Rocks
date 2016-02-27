# [Penlight](https://github.com/stevedonovan/Penlight)

This is a patchset for Penlight. Currently tracking scm-1.

## Current issues
 - Home directory is resolved to "/" instead.
 - As with all of BSRocks, `getmetatable` doesn't work on strings, do you can't add custom operators.

### Changes to tests/other issues
 - `test-date` does not run with a different local
 - `test-fenv` does not run `lua -v`
 - `test-lapp` does not run `=` as `string.find` appears to break on these strings. I can't reproduce outside the test.
 - `test-lapp` does type differently
 - `test-pretty-number` isn't run (`string.format` issues)
 - `test.pretty` isn't run due to debug hooks.
 - `test-pylib` doesn't test string extension methods
 - `test-strict` isn't run as we cannot detect top level functions
 - `test-stringio` changes the format specifier slightly
 - `test-text` doesn't test the `%` operator.
