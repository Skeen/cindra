local assert = require('__factorio-test__.luassert.assert')

assert._COPYRIGHT   = "Copyright (c) 2018 Olivine Labs, LLC."
assert._DESCRIPTION = "Extends Lua's built-in assertions to provide additional tests and the ability to create your own."
assert._VERSION     = "Luassert 1.8.0"

-- load basic asserts
require('__factorio-test__.luassert.assertions')
require('__factorio-test__.luassert.modifiers')
require('__factorio-test__.luassert.array')
require('__factorio-test__.luassert.matchers.init')
require('__factorio-test__.luassert.formatters.init')


-- load default language
require('__factorio-test__.luassert.languages.en')

_G.assert = assert
spy = require("__factorio-test__.luassert.spy")
mock = require("__factorio-test__.luassert.mock")
stub = require("__factorio-test__.luassert.stub")
match = require("__factorio-test__.luassert.match")

return assert
