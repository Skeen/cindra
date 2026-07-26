local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 1,["6"] = 2,["7"] = 3,["8"] = 4,["9"] = 5,["10"] = 6});
local ____exports = {}
require("control.deprecated-cli-check")
require("control.start-tests")
require("control.mod-select-gui")
require("control.test-gui")
require("control.auto-start")
require("control.udp-rerun")
return ____exports
