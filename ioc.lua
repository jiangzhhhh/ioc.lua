local M = {}

local verboseLog
local function print(...)
	if verboseLog then
		_G.print('[ioc]', ...)
	end
end

local function error(msg, level)
	_G.error('[ioc]' .. msg, level or 3)
end

local function assert(cond, msg)
	if msg then
		_G.assert(cond, '[ioc]' .. msg)
	else
		_G.assert(cond)
	end
end

local function findLoader(name)
	local msg = {}
	for _, loader in ipairs(package.searchers) do
		local f, extra = loader(name)
		local t = type(f)
		if t == "function" then
			return f, extra
		elseif t == "string" then
			table.insert(msg, f)
		end
	end
	error(string.format("module '%s' not found:%s", name, table.concat(msg)))
end

local makePlaceholder
local placeholder_mt = {
	__index = function(t, k) return makePlaceholder(k, t.name) end,
	__newindex = error,
	__tostring = function(self) return string.format('placeholder[%s]', self.name) end,
	__call = function(self) error(string.format("%s can't be call", tostring(self))) end,
}
makePlaceholder = function(key, prefix)
	if prefix then
		key = prefix .. '.' .. key
	end
	return setmetatable({name=key}, placeholder_mt)
end

local function findObject(root, path)
	local split = {}
	path:gsub('[^%.]+', function(x) split[#split+1]=x end)
	local find = nil
	for i=1,#split,1 do
		local entry = split[i]
		if find == nil then
			find = root[entry]
		else
			find = find[entry]
		end
		if find == nil then
			break
		end
	end
	return find
end

local resolved = false
local sandbox_env_mt={
	__index = function(env, key)
		local lazy_import = rawget(env, 'lazy_import')
		if lazy_import then
			local fqn = lazy_import[key]
			if fqn then
				local find = findObject(_G, fqn)
				print('lazy import', fqn, find)
				rawset(env, key, find)
				return find
			end
		end
		return _G[key]
	end,
	__newindex = function(t,k,v) _G[k] = v end,
	-- __newindex = function() error("can't set global") end,
	__tostring = function() return "sandbox env" end
}
local function getEnv()
	local f = debug.getinfo(3).func
	local upname,env = debug.getupvalue(f, 1)
	assert(upname == '_ENV')
	assert(type(env)=='table')
	assert(getmetatable(env)==sandbox_env_mt)
	return env
end
local placeholders = {}
local function inject(name)
	local env = getEnv()
	local placeholder = placeholders[name]
	if placeholder then
		return placeholder
	end
	placeholder = makePlaceholder(name, nil)
	placeholders[name] = placeholder
	return placeholder
end
local lazy_mt = {
	__index = function() error("lazy object can't be index") end,
	__newindex = function() error("lazy object can't be newindex") end,
	__call = function() error("lazy object can't be call") end,
	__tostring = function(self) return "[lazy]" .. self.name end
}
local function lazy(name)
	return setmetatable({name=name}, lazy_mt)
end
local function using(aliasTable)
	assert(type(aliasTable)=='table', 'usage: using{key = lazy \'xxx\'}')
	local env = getEnv()
	local lazy_import = rawget(env, 'lazy_import')
	assert(lazy_import)
	for k,v in pairs(aliasTable)do
		assert(type(k) == 'string', 'must be string')
		assert(type(v) == 'table' and getmetatable(v) == lazy_mt, 'must use `lazy` function')
		lazy_import[k] = v.name
	end
end

local ioc_loaded = {}
local ioc_moduals = {}
local ioc_require
ioc_require = function(name)
	assert(type(name) == "string")
	local _R = debug.getregistry()
	local _LOADED =_R['_LOADED']
	local mod = _LOADED[name] or ioc_loaded[name]
	if mod then
		return mod
	end

	local loader, arg = findLoader(name)
	local env = debug.getupvalue(loader, 1)
	local sandbox = setmetatable({
		--for inject
		inject = inject,

		--for lazy import
		lazy_import = {},
		using = using,
		lazy = lazy,

		require = ioc_require,
	}, sandbox_env_mt)

	if env == "_ENV" then
		debug.setupvalue(loader, 1, sandbox)
	end
	mod = loader(name, arg) or true
	local tt = type(mod)
	if tt == 'table' or tt == 'function' then
		ioc_moduals[mod] = sandbox
		if resolved then
			M.resolve(mod)
		end
	end
	ioc_loaded[name] = mod
	_LOADED[name] = mod
	return mod
end
M.require = ioc_require

local function isPlaceholder(value)
	local tt = type(value)
	return tt == 'table' and getmetatable(value) == placeholder_mt
end
local function enumAllPlaceholder(mod)
	local upvalues = {}
	local table_values = {}

	local env = ioc_moduals[mod]
	local visited = {
		[env]=true,
		[table]=true,
		[string]=true,
		[debug]=true,
		[string]=true,
		[os]=true,
		[coroutine]=true,
		[debug.getregistry()]=true,
		[_G]=true,
	}
	local function iterator(value)
		if visited[value] then
			return
		end
		visited[value] = true

		local tt = type(value)
		if tt == 'function' then
			local i = 1
			while true do
				local name, uv = debug.getupvalue(value, i)
				if name == nil or name == "" then
					break
				else
					if isPlaceholder(uv) then
						table.insert(upvalues, {uv, value, i})
					else
						local vt = type(uv)
						if vt == "function" or vt == "table" then
							iterator(uv)
						end
					end
				end
				i = i + 1
			end
		elseif tt == 'table' then
			for k,v in pairs(value)do
				if isPlaceholder(v) then
					table.insert(table_values, {v, value, k})
				else
					iterator(v)
				end
			end
		end
	end
	iterator(mod)
	return upvalues,table_values
end

local instanceProvider = {}
local resolveValueCache
local function resolveValue(placeholder)
	local name = placeholder.name
	if resolveValueCache and resolveValueCache[name] then
		return resolveValueCache[name]
	end
	local find = instanceProvider[name]
	if find == nil then
		find = findObject(_G, name)
	end
	if resolveValueCache then
		resolveValueCache[name] = find
	end

	if find == nil then
		print(string.format("%s can't resolve", tostring(placeholder)))
	else
		print(string.format('resolve %s -> %s', tostring(placeholder), find))
	end

	return find
end

local UVAddresses = {}
local TVAddresses = {}
local function makeUVAddress(f, i) return tostring(f) .. ':' .. tostring(i) end
local function makeTVAddress(t,k) return tostring(t) .. ':' .. tostring(v) end
function M.resolve(mod)
	assert(mod)
	--gather
	local upvalues,table_values = enumAllPlaceholder(mod)
	for _,v in ipairs(upvalues)do
		local placeholder,f,i = table.unpack(v)
		local name = placeholder.name
		UVAddresses[name] = UVAddresses[name]or {}
		UVAddresses[name][makeUVAddress(f,i)] = {placeholder, f, i}
	end
	for _,v in ipairs(table_values)do
		local placeholder,tab,key = table.unpack(v)
		local name = placeholder.name
		TVAddresses[name] = TVAddresses[name]or {}
		TVAddresses[name][makeTVAddress(tab,key)] = {placeholder, tab, key}
	end

	--resolve
	for _,addresses in pairs(UVAddresses)do
		for _,v in pairs(addresses)do
			local placeholder,f,i = table.unpack(v)
			local value = resolveValue(placeholder)
			debug.setupvalue(f, i, value)
		end
	end
	for _,addresses in pairs(TVAddresses)do
		for _,v in pairs(addresses)do
			local placeholder,tab,key = table.unpack(v)
			local value = resolveValue(placeholder)
			tab[key] = value
		end
	end
end

function M.resolveAll()
	resolveValueCache = {}
	resolved = true
	for mod,_ in pairs(ioc_moduals)do
		M.resolve(mod)
	end
	resolveValueCache = nil
end

function M.provide(name, value)
	instanceProvider[name] = value
end

function M.verbose(yes)
	verboseLog = yes
end

return M