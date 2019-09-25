local ioc = require 'ioc'
local mod = ioc.require 'mod'

local function silence()end
local function trace(str) return print("[TRACE]", str) end
local function warnning(str) return print("[WARNNING]", str) end
local function error(str) return print("[ERROR]", str) end

ioc.verbose(true)
ioc.provide('$LOG', trace)
ioc.provide('$WARNNING', warnning)
ioc.provide('$ERROR', error)
ioc.provide('$encrypt.encode', function(x) return x end)
ioc.provide('$encrypt.decode', function(x) return x end)
ioc.resolveAll()
mod.output('1111111')

print('-----------------------------------------')

ioc.provide('$LOG', silence)
ioc.provide('$WARNNING', silence)
ioc.provide('$ERROR', silence)
ioc.resolveAll()
mod.output('2222222')
