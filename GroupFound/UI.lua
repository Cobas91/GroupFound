-- GroupFound UI
-- Hauptfenster, aufrufbar per /gf. Enthält zwei Tabs: Mitglieder (zusammengefasste
-- Whitelist/Gruppen-Liste inkl. Inventar/Bank/Berufe-Detailansicht) und Historie
-- (gemeinsame Fund-Historie). Tab-Inhalte werden in GroupUI.lua gebaut.
-- Texte kommen aus Locales.lua (GroupFound.L), passend zur aktuellen Client-Sprache (GetLocale()).

GroupFound = GroupFound or {}
local L = GroupFound.L

local frame

------------------------------------------------------------
-- Tab-Leiste (Mitglieder / Historie)
------------------------------------------------------------

local TAB_ORDER = { "members", "history" }
local TAB_LABEL_KEYS = { members = "TAB_MEMBERS", history = "TAB_HISTORY" }

local function CreateTabButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(26)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(1, 1, 1, 0.03)

    btn.underline = btn:CreateTexture(nil, "ARTWORK")
    btn.underline:SetPoint("BOTTOMLEFT", 0, 0)
    btn.underline:SetPoint("BOTTOMRIGHT", 0, 0)
    btn.underline:SetHeight(2)
    btn.underline:SetColorTexture(1, 0.82, 0, 1)
    btn.underline:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")

    btn:SetScript("OnEnter", function()
        if not btn.active then btn.bg:SetColorTexture(1, 1, 1, 0.08) end
    end)
    btn:SetScript("OnLeave", function()
        if not btn.active then btn.bg:SetColorTexture(1, 1, 1, 0.03) end
    end)

    return btn
end

function GroupFound.SelectTab(tabName)
    if not frame then return end
    tabName = tabName or frame.activeTab or "members"
    if not frame.panels[tabName] then tabName = "members" end
    frame.activeTab = tabName

    for name, panel in pairs(frame.panels) do
        panel:SetShown(name == tabName)
    end

    for name, btn in pairs(frame.tabs) do
        local active = (name == tabName)
        btn.active = active
        btn.underline:SetShown(active)
        if active then
            btn.bg:SetColorTexture(1, 0.82, 0, 0.16)
            btn.text:SetTextColor(1, 0.82, 0)
        else
            btn.bg:SetColorTexture(1, 1, 1, 0.03)
            btn.text:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

-- Alias fuer Aufrufer, die noch GroupFound.RefreshUI() erwarten (Core.lua add/remove).
function GroupFound.RefreshUI()
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

------------------------------------------------------------
-- Fenster aufbauen
------------------------------------------------------------

local function BuildFrame()
    frame = CreateFrame("Frame", "GroupFoundFrame", UIParent, "BackdropTemplate")
    frame:SetSize(460, 720)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    tinsert(UISpecialFrames, "GroupFoundFrame")

    -- Icon + Titel
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("TOPLEFT", 18, -14)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    title:SetText("GroupFound")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetText(L.SUBTITLE)

    -- Schließen-Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    ------------------------------------------------------------
    -- Tab-Leiste
    ------------------------------------------------------------
    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 18, -64)
    tabBar:SetPoint("TOPRIGHT", -18, -64)
    tabBar:SetHeight(26)

    frame.tabs = {}
    local tabWidth = 424 / #TAB_ORDER
    for i, tabName in ipairs(TAB_ORDER) do
        local btn = CreateTabButton(tabBar)
        btn:SetWidth(tabWidth)
        btn:SetPoint("TOPLEFT", tabBar, "TOPLEFT", (i - 1) * tabWidth, 0)
        btn.text:SetText(L[TAB_LABEL_KEYS[tabName]])
        btn:SetScript("OnClick", function() GroupFound.SelectTab(tabName) end)
        frame.tabs[tabName] = btn
    end

    ------------------------------------------------------------
    -- Panel-Container (nur eines gleichzeitig sichtbar)
    ------------------------------------------------------------
    local membersPanel = CreateFrame("Frame", nil, frame)
    membersPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -90)
    membersPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 12)

    local historyPanel = CreateFrame("Frame", nil, frame)
    historyPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -90)
    historyPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 12)
    historyPanel:Hide()

    frame.membersPanel = membersPanel
    frame.historyPanel = historyPanel
    frame.panels = { members = membersPanel, history = historyPanel }

    ------------------------------------------------------------
    -- Tab-Inhalte (GroupUI.lua)
    ------------------------------------------------------------
    if GroupFound.BuildMembersPanel then
        GroupFound.BuildMembersPanel(membersPanel)
    end
    if GroupFound.BuildHistoryPanel then
        GroupFound.BuildHistoryPanel(historyPanel)
    end

    frame.activeTab = "members"
end

function GroupFound.ToggleUI(tabName)
    if not frame then
        BuildFrame()
    end
    if tabName then
        frame:Show()
        GroupFound.SelectTab(tabName)
    elseif frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        GroupFound.SelectTab(frame.activeTab or "members")
    end
end
