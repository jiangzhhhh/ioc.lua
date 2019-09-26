local encrypt = require 'encrypt'
local Debug ={
	Log = inject '$LOG',
	Warnning = inject '$WARNNING',
	Error = inject '$ERROR',
}
local assert = inject 'assert'
lazy{
	print = import '_G.print',
	debug = import '_G.debug',
	luckNumber = function() return math.random() end,
}
lazy{anthor_print = import '_G.print'}

local M = {}

function M.output(str)
	local x = encrypt.encode(str)
	local y = encrypt.decode(x)
	assert(y == str)

	Debug.Log(str)
	Debug.Warnning(str)
	Debug.Error(str)
	print('debug lib:', debug)
	anthor_print('short_src:', debug.getinfo(1).short_src)
	print('my luck number:', luckNumber)
end

return M