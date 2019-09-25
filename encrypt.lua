local encode = inject '$encrypt.encode'
local decode = inject '$encrypt.decode'

local M = {}

function M.encode(a)
	return encode(a)
end

function M.decode(a)
	return decode(a)
end

return M