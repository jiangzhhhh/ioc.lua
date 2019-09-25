local attack_impl = inject '$attack'

local M = {}

function M.attack(who, target)
	print(who, attack_impl, 'to', target)
end

return M