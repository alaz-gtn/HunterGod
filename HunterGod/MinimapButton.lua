local _, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\HunterGod\\media\\icon"

local db
local button = CreateFrame("Button", "HunterGodMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(20, 20)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 7, -5)
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetTexture(ICON)
icon:SetPoint("TOPLEFT", 7, -5)
local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetPoint("TOPLEFT")

local function Place()
	local angle = math.rad(db.angle)
	local radius = Minimap:GetWidth() / 2 + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Dragging moves the button around the edge of the minimap
local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	db.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
	Place()
end

button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FollowCursor) end)
button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

button:SetScript("OnClick", function(_, mouse)
	if mouse == "RightButton" then
		ns.SetUnlocked(not ns.unlocked)
	elseif ns.ToggleOptions then
		ns.ToggleOptions()
	end
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("HunterGod")
	if ns.IsHunter() then
		local count = ns.AmmoCount()
		GameTooltip:AddLine(format(L.TIP_AMMO, count), 1, 1, 1)
		local foods, total = ns.PetFoods()
		if foods then
			GameTooltip:AddLine(format(L.TIP_PET_FOOD, total), 1, 1, 1)
		end
	end
	GameTooltip:AddLine(L.TIP_LEFT, 0.4, 0.7, 1)
	GameTooltip:AddLine(ns.unlocked and L.TIP_RIGHT_LOCK or L.TIP_RIGHT_UNLOCK, 0.4, 0.7, 1)
	GameTooltip:AddLine(L.TIP_DRAG, 0.6, 0.6, 0.6)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

function ns.UpdateMinimapButton()
	button:SetShown(not db.hide)
	Place()
end

local function ToggleButton()
	db.hide = not db.hide
	ns.UpdateMinimapButton()
end
ns.commands.button = ToggleButton
ns.commands.boton = ToggleButton
ns.commands["botón"] = ToggleButton

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	db = ns.db.minimapButton
	ns.UpdateMinimapButton()
end)
