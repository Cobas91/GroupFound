-- GroupFound UI
-- Einstellungsfenster für die Whitelist, aufrufbar per /gf
-- Texte kommen aus Locales.lua (GroupFound.L), passend zur aktuellen Client-Sprache (GetLocale()).

GroupFound = GroupFound or {}
local L = GroupFound.L

local ROW_HEIGHT = 22
local ROW_WIDTH = 340
local frame

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

------------------------------------------------------------
-- Zeilen (Whitelist-Einträge)
------------------------------------------------------------

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.03)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 0.82, 0, 0.10)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWidth(ROW_WIDTH - 34)

    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(16, 16)
    row.removeBtn:SetPoint("RIGHT", -6, 0)
    row.removeBtn:SetNormalFontObject("GameFontNormal")
    row.removeBtn:SetHighlightFontObject("GameFontHighlight")
    row.removeBtn:SetText("|cffff5555x|r")
    row.removeBtn:SetScript("OnEnter", function(self)
        row.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.REMOVE_TOOLTIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    row.removeBtn:SetScript("OnLeave", function()
        row.highlight:Hide()
        GameTooltip:Hide()
    end)

    row:SetScript("OnEnter", function() row.highlight:Show() end)
    row:SetScript("OnLeave", function() row.highlight:Hide() end)
    row.highlight:Hide()

    return row
end

local rowPool = {}

local function GetRow(index, parent)
    local row = rowPool[index]
    if not row then
        row = CreateRow(parent)
        rowPool[index] = row
    end
    return row
end

function GroupFound.RefreshUI()
    if not frame or not frame:IsShown() then return end

    local list = GroupFound.GetSortedList()
    frame.countText:SetText(L.COUNT_FMT:format(#list))
    frame.emptyText:SetShown(#list == 0)

    for i, entry in ipairs(list) do
        local row = GetRow(i, frame.content)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.text:SetText(entry.display)
        row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.015)
        row.removeBtn:SetScript("OnClick", function()
            GroupFound.RemoveByKey(entry.key)
            GroupFound.RefreshUI()
        end)
        row:Show()
    end

    for i = #list + 1, #rowPool do
        rowPool[i]:Hide()
    end

    frame.content:SetHeight(math.max(1, #list * ROW_HEIGHT))
end

------------------------------------------------------------
-- Kleine Bauhelfer
------------------------------------------------------------

local function CreateDivider(parent, yOffset)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, yOffset)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, yOffset)
    line:SetHeight(1)
    return line
end

------------------------------------------------------------
-- Fenster aufbauen
------------------------------------------------------------

local function BuildFrame()
    frame = CreateFrame("Frame", "GroupFoundFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 620)
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

    -- Hinweistext
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 18, -58)
    hint:SetPoint("TOPRIGHT", -18, -58)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.HINT)

    CreateDivider(frame, -98)

    -- Listen-Kopfzeile
    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 18, -108)
    listLabel:SetText(L.LIST_LABEL)

    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("TOPRIGHT", -18, -108)
    frame.countText = countText

    -- Listenpanel (Inset) + ScrollFrame
    local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 16, -126)
    inset:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -16, -364)

    local scrollFrame = CreateFrame("ScrollFrame", "GroupFoundScrollFrame", inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(ROW_WIDTH, 1)
    scrollFrame:SetScrollChild(content)
    frame.content = content

    local emptyText = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER", inset, "CENTER", -10, 0)
    emptyText:SetText(L.EMPTY_LIST)
    emptyText:SetJustifyH("CENTER")
    frame.emptyText = emptyText

    -- Eingabefeld zum Hinzufügen. Ist es leer, wird stattdessen das aktuelle
    -- Ziel verwendet (sofern es ein Spieler ist) - ein Button/Befehl für beides.
    local editBox = CreateFrame("EditBox", "GroupFoundAddEditBox", frame, "InputBoxTemplate")
    editBox:SetSize(250, 20)
    editBox:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 8, -14)
    editBox:SetAutoFocus(false)
    frame.editBox = editBox

    local function AddFromEditBoxOrTarget()
        local text = editBox:GetText()
        if text and trim(text) ~= "" then
            if GroupFound.AddName(text) then
                editBox:SetText("")
                GroupFound.RefreshUI()
            end
        else
            GroupFound.AddCurrentTarget()
        end
        editBox:ClearFocus()
    end

    editBox:SetScript("OnEnterPressed", AddFromEditBoxOrTarget)

    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(96, 22)
    addBtn:SetPoint("LEFT", editBox, "RIGHT", 12, 0)
    addBtn:SetText(L.ADD_BUTTON)
    addBtn:SetScript("OnClick", AddFromEditBoxOrTarget)

    local addHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    addHint:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -6)
    addHint:SetWidth(340)
    addHint:SetJustifyH("LEFT")
    addHint:SetText(L.ADD_HINT)

    -- Ab hier haengt alles relativ am vorherigen Element (top-down).
    -- Jede Trennlinie/Textbox verwendet nur EINEN Ankerpunkt (plus SetWidth),
    -- damit nichts überlappt und keine zwei Anker mit unterschiedlichem Y
    -- an verschiedenen Eltern-Frames kollidieren.
    local divider2 = CreateFrame("Frame", nil, frame)
    divider2:SetPoint("TOPLEFT", addHint, "BOTTOMLEFT", 0, -12)
    divider2:SetSize(384, 1)
    local divider2Tex = divider2:CreateTexture(nil, "ARTWORK")
    divider2Tex:SetAllPoints()
    divider2Tex:SetColorTexture(1, 0.82, 0, 0.25)

    -- Der Schutz ist immer aktiv - es gibt bewusst keine Ein/Aus-Schalter dafür,
    -- ein Hardcore-Handelsschutz, den man selbst abschalten kann, waere sinnlos.
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", 6, -12)
    statusText:SetWidth(372)
    statusText:SetJustifyH("LEFT")
    statusText:SetTextColor(0.3, 1, 0.3)
    statusText:SetText(L.PROTECTION_ALWAYS_ON)

    -- Trennlinie + Befehlsübersicht, an den Statustext gekettet (top-down),
    -- damit hier nichts überlappen kann.
    local divider3 = CreateFrame("Frame", nil, frame)
    divider3:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -14)
    divider3:SetSize(384, 1)
    local divider3Tex = divider3:CreateTexture(nil, "ARTWORK")
    divider3Tex:SetAllPoints()
    divider3Tex:SetColorTexture(1, 0.82, 0, 0.25)

    local cmdLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdLabel:SetPoint("TOPLEFT", divider3, "BOTTOMLEFT", 6, -10)
    cmdLabel:SetText(L.CMD_LABEL)

    local cmdList = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdList:SetPoint("TOPLEFT", cmdLabel, "BOTTOMLEFT", 0, -6)
    cmdList:SetWidth(384)
    cmdList:SetJustifyH("LEFT")
    cmdList:SetSpacing(3)
    cmdList:SetText(
        L.CMD_TOGGLE .. "\n" ..
        L.CMD_ADD .. "\n" ..
        L.CMD_ADD_TARGET .. "\n" ..
        L.CMD_REMOVE .. "\n" ..
        L.CMD_LIST
    )
end

function GroupFound.ToggleUI()
    if not frame then
        BuildFrame()
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        GroupFound.RefreshUI()
    end
end
