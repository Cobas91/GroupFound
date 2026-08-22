-- GroupFound Minimap Button
-- Zeigt einen kleinen Button am Minimap-Rand. Linksklick öffnet/schließt die /gf-UI.

GroupFound = GroupFound or {}
local L = GroupFound.L

local button

local function UpdatePosition()
    if not button then return end
    local angle = math.rad(GroupFoundDB.minimapPos or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    local x, y = math.cos(angle) * radius, math.sin(angle) * radius
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function OnDragUpdate(self)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    GroupFoundDB.minimapPos = math.deg(math.atan2(py - my, px - mx))
    UpdatePosition()
end

local function CreateButton()
    if button then return end

    button = CreateFrame("Button", "GroupFoundMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetPoint("TOPLEFT", 0, 0)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            GroupFound.ToggleUI()
        elseif mouseButton == "RightButton" then
            GroupFound.ToggleUI("members")
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("GroupFound")
        GameTooltip:AddLine(L.MINIMAP_TOOLTIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
end

-- PLAYER_LOGIN feuert erst, nachdem Core.lua per ADDON_LOADED bereits
-- GroupFound.InitDB() aufgerufen hat, GroupFoundDB.minimapPos existiert also sicher.
local minimapEventFrame = CreateFrame("Frame")
minimapEventFrame:RegisterEvent("PLAYER_LOGIN")
minimapEventFrame:SetScript("OnEvent", CreateButton)
