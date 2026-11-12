-- Every user-facing string of the addon, one per line: the keys of W.L. Not a harness by itself (tools/ui.lua
-- uses it to check that the ptBR table is complete); run it to list what a new locale has to translate.
--   luajit tools/keys.lua
local function Keys(W)
	local keys, seen = {}, {}
	local function add(k)
		if type(k) == "string" and k ~= "" and not seen[k] then seen[k] = true; keys[#keys + 1] = k end
	end
	for _, file in ipairs({ "Ring", "Window", "Views", "Pins", "Toast", "Options", "Entry" }) do
		local f = assert(io.open("UI/" .. file .. ".lua"))
		local src = f:read("*a")
		f:close()
		for k in src:gmatch('L%["(.-)"%]') do add((k:gsub("\\n", "\n"):gsub('\\"', '"'))) end
		-- strings reached through a table: filter labels and reasons
		for k in src:gmatch('{ "%l+", "(.-)", function') do add(k) end
		for k in src:gmatch('\n\t[%l_]+ = "(.-)",') do add(k) end
		for k in src:gmatch('or "([^"\n]+)"%]') do add(k) end
	end
	for _, t in ipairs(W.TIERS) do add(t) end
	for _, o in ipairs(W.OBJECTS) do add(o[3]); add(o[4]) end
	return keys
end

if arg and arg[0] and arg[0]:find("keys%.lua$") then
	local S = dofile("tools/wowstub.lua")
	local W = S.load("Core/")
	for _, k in ipairs(Keys(W)) do io.write((k:gsub("\n", "\\n")), "\n") end
end
return Keys
