local ioc = require 'ioc'
local mod = ioc.require 'mod2'

ioc.provide('$attack', 'shot')
ioc.resolveAll()
mod.attack('I', 'you')

ioc.provide('$attack', 'chop')
ioc.resolveAll()
mod.attack('I', 'you')
