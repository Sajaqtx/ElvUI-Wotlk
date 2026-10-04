--[[
	ElvUI Wotlk: a LibStub of ElvUI's own (loaded right after LibStub.lua, before any library).

	ElvUI v15 embeds the latest Ace3 (AceGUI, AceConfigDialog, AceDB...): in the shared LibStub they would upgrade the
	3.3.5 copies the other addons of the session use (Details, ColorPickerAdvanced...) and break them. ElvUI's
	libraries register here instead, so the other addons never see them. The libraries made to be shared stay in
	the client's LibStub: the media registry (LibSharedMedia: the fonts and textures of other addons), the data
	brokers (LibDataBroker: their minimap / data text feeds) and their CallbackHandler. A library ElvUI does not
	embed (Masque, LibDBIcon...) is looked up in the shared LibStub.
]]

local env = ElvUI335_ENV
local realG = getmetatable(env).__index
local shared = realG.LibStub

local tonumber, strmatch, pairs, error, assert, type = tonumber, string.match, pairs, error, assert, type

local SHARED = {
	["CallbackHandler-1.0"] = true,
	["LibSharedMedia-3.0"] = true,
	["LibDataBroker-1.1"] = true,
}

local LibStub = {libs = {}, minors = {}, minor = 2}

function LibStub:NewLibrary(major, minor)
	if (SHARED[major]) then return shared:NewLibrary(major, minor) end

	assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
	minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")

	local oldminor = self.minors[major]
	if (oldminor and oldminor >= minor) then return nil end
	self.minors[major], self.libs[major] = minor, self.libs[major] or {}
	return self.libs[major], oldminor
end

function LibStub:GetLibrary(major, silent)
	if (self.libs[major]) then return self.libs[major], self.minors[major] end
	if (shared and shared.libs[major]) then return shared:GetLibrary(major, silent) end
	if (not silent) then
		error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
	end
end

function LibStub:IterateLibraries()
	return pairs(self.libs)
end

setmetatable(LibStub, {__call = LibStub.GetLibrary})
rawset(env, "LibStub", LibStub)
