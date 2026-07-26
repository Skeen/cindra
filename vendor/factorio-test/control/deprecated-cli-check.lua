local ____lualib = require("lualib_bundle")
local __TS__SourceMapTraceBack = ____lualib.__TS__SourceMapTraceBack
__TS__SourceMapTraceBack(debug.getinfo(1).short_src, {["5"] = 3,["6"] = 3,["7"] = 5,["8"] = 6,["9"] = 23,["10"] = 24,["11"] = 25,["12"] = 26,["13"] = 27});
local ____exports = {}
local ____opt_0 = settings.startup["factorio-test-auto-start"]
local deprecatedAutoStart = ____opt_0 and ____opt_0.value
if deprecatedAutoStart then
    local message = "\n================================================================================\n  INCOMPATIBLE CLI VERSION\n================================================================================\n\n  factorio-test mod version 3.0+ is not compatible with factorio-test-cli 2.x.\n\n  Options:\n    - Upgrade to v3.0 (breaking changes, see changelog):\n        npm install factorio-test-cli@latest\n\n    - Stay on 2.x by upgrading CLI to 2.0.1:\n        npm install factorio-test-cli@2\n\n================================================================================\n"
    print("FACTORIO-TEST-MESSAGE-START")
    log(message)
    print("FACTORIO-TEST-MESSAGE-END")
    print("FACTORIO-TEST-RESULT:incompatible cli version")
    error("FACTORIO-TEST-EXIT")
end
return ____exports
