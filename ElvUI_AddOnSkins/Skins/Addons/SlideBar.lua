setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins").Skins610 -- ElvUI Wotlk: the 6.10 skin calls on this version (Skins335 adapter)
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("SlideBar") then return end

-- SlideBar 5.8.4723
-- https://www.curseforge.com/wow/addons/auctionator/files/426882

S:AddCallbackForAddon("SlideBar", "SlideBar", function()
	if not E.private.addOnSkins.SlideBar then return end

	local lib = LibStub("SlideBar", true)
	if not lib then return end

	lib.frame:SetTemplate("Transparent")

	local TT = E:GetModule("Tooltip")
	hooksecurefunc(lib, "SetTip", function(self)
		TT:SetStyle(self.tooltip)
	end)
end)