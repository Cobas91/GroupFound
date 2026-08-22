-- GroupFound GroupUI
-- Baut die Inhalte der Tabs "Mitglieder" (zusammengefasste Whitelist/Gruppen-Liste,
-- Einladen, Detailansicht mit Inventar/Bank/Berufen) und "Historie" (gemeinsame
-- Fund-Historie), die von UI.lua in das Hauptfenster eingehängt werden. Kein eigenes
-- Toplevel-Fenster. Die Whitelist (Core.lua, GroupFoundDB.whitelist) ist die einzige
-- Mitgliederliste - wer auf ihr steht, gehört zur Gruppe.

GroupFound = GroupFound or {}
local L = GroupFound.L

local MEMBER_ROW_WIDTH = 380
local MEMBER_ROW_HEIGHT = 32
local HISTORY_ROW_WIDTH = 380
local HISTORY_ROW_HEIGHT = 42
local ICON_SIZE = 28
local ICON_SPACING = 6

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

local function FormatRelativeTime(ts)
    if not ts then return nil end
    local diff = time() - ts
    if diff < 0 then diff = 0 end
    if diff < 60 then
        return L.TIME_JUST_NOW
    elseif diff < 3600 then
        return L.TIME_MINUTES_FMT:format(math.floor(diff / 60))
    elseif diff < 86400 then
        return L.TIME_HOURS_FMT:format(math.floor(diff / 3600))
    elseif diff < 172800 then
        return L.TIME_YESTERDAY
    else
        return L.TIME_DAYS_FMT:format(math.floor(diff / 86400))
    end
end

------------------------------------------------------------
-- Modul-Zustand (ein einziges Fenster, kein Mehrfach-Instanzieren nötig -
-- analog zum bestehenden "local frame" Muster in UI.lua)
------------------------------------------------------------

local membersUI = {}
local historyUI = {}
local memberRowPool = {}
local historyRowPool = {}
local iconCellPool = {}
local textRowPool = {}
local profRowPool = {}
local nextIconIndex, nextTextIndex, nextProfIndex = 0, 0, 0
local expandedProfessions = {}

local function CreateFlowDivider(parent, anchorTo, xOffset, yOffset, width)
    local d = CreateFrame("Frame", nil, parent)
    d:SetSize(width, 1)
    d:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", xOffset, yOffset)
    local tex = d:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetColorTexture(1, 0.82, 0, 0.25)
    return d
end

------------------------------------------------------------
-- Mitglieder-Liste (= Whitelist, Core.lua GroupFoundDB.whitelist)
------------------------------------------------------------

local function CreateMemberRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(MEMBER_ROW_WIDTH, MEMBER_ROW_HEIGHT)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.03)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 0.82, 0, 0.10)
    row.highlight:Hide()

    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(10, 10)
    row.dot:SetPoint("LEFT", 8, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.dot, "TOPRIGHT", 8, 2)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(MEMBER_ROW_WIDTH - 66)

    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("BOTTOMLEFT", row.dot, "BOTTOMRIGHT", 8, -2)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWidth(MEMBER_ROW_WIDTH - 66)

    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetSize(16, 16)
    row.removeBtn:SetPoint("RIGHT", -6, 0)
    row.removeBtn:SetNormalFontObject("GameFontNormal")
    row.removeBtn:SetHighlightFontObject("GameFontHighlight")
    row.removeBtn:SetText("|cffff5555x|r")
    row.removeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.REMOVE_TOOLTIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    row.removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row:SetScript("OnEnter", function(self)
        row.highlight:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.MEMBER_ROW_CLICK_HINT, 1, 1, 1)
        GameTooltip:AddLine(L.ONLINE_STATUS_TOOLTIP, 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        row.highlight:Hide()
        GameTooltip:Hide()
    end)

    return row
end

local function GetMemberRow(index, parent)
    local row = memberRowPool[index]
    if not row then
        row = CreateMemberRow(parent)
        memberRowPool[index] = row
    end
    return row
end

local function RefreshMemberList()
    if not membersUI.content then return end

    local list = GroupFound.GetSortedList()
    membersUI.emptyText:SetShown(#list == 0)
    if membersUI.listLabel then
        membersUI.listLabel:SetText(L.TAB_MEMBERS .. "  " .. L.COUNT_FMT:format(#list))
    end

    for i, entry in ipairs(list) do
        local row = GetMemberRow(i, membersUI.content)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", membersUI.content, "TOPLEFT", 0, -(i - 1) * MEMBER_ROW_HEIGHT)
        row.name:SetText(entry.display)
        row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.015)

        if GroupFound.IsMemberRecentlyActive(entry.key) then
            row.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
        else
            row.dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
        end
        local lastSeen = GroupFound.GetMemberLastSeen(entry.key)
        row.sub:SetText(lastSeen and FormatRelativeTime(lastSeen) or "")

        row.removeBtn:SetScript("OnClick", function()
            GroupFound.RemoveByKey(entry.key)
            if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
        end)
        row:SetScript("OnClick", function() GroupFound.ShowMemberDetail(entry.key) end)
        row:Show()
    end

    for i = #list + 1, #memberRowPool do
        memberRowPool[i]:Hide()
    end

    membersUI.content:SetHeight(math.max(1, #list * MEMBER_ROW_HEIGHT))
end

------------------------------------------------------------
-- Historie
------------------------------------------------------------

local function CreateHistoryRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(HISTORY_ROW_WIDTH, HISTORY_ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.03)

    row.qualityBar = row:CreateTexture(nil, "ARTWORK")
    row.qualityBar:SetPoint("TOPLEFT", 0, 0)
    row.qualityBar:SetPoint("BOTTOMLEFT", 0, 0)
    row.qualityBar:SetWidth(3)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 10, 0)

    row.iconBtn = CreateFrame("Frame", nil, row)
    row.iconBtn:SetAllPoints(row.icon)
    row.iconBtn:EnableMouse(true)
    row.iconBtn:SetScript("OnEnter", function(self)
        if row.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(row.itemLink)
            GameTooltip:Show()
        end
    end)
    row.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.itemText:SetJustifyH("LEFT")
    row.itemText:SetWidth(HISTORY_ROW_WIDTH - 60)

    row.subText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.subText:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
    row.subText:SetJustifyH("LEFT")
    row.subText:SetWidth(HISTORY_ROW_WIDTH - 60)

    return row
end

local function GetHistoryRow(index, parent)
    local row = historyRowPool[index]
    if not row then
        row = CreateHistoryRow(parent)
        historyRowPool[index] = row
    end
    return row
end

local function RefreshHistoryList()
    if not historyUI.content then return end

    local hasMembers = GroupFoundDB and next(GroupFoundDB.whitelist) ~= nil
    local list = GroupFound.GetSortedHistory()
    historyUI.emptyText:SetShown(#list == 0)
    historyUI.emptyText:SetText(hasMembers and L.HISTORY_EMPTY or L.NO_GROUP_YET)

    for i, entry in ipairs(list) do
        local row = GetHistoryRow(i, historyUI.content)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", historyUI.content, "TOPLEFT", 0, -(i - 1) * HISTORY_ROW_HEIGHT)
        row.itemLink = entry.itemLink
        row.itemText:SetText(entry.itemLink or "")
        row.subText:SetText(L.FOUND_BY_FMT:format(entry.finder or "?") .. "   " .. (FormatRelativeTime(entry.ts) or ""))

        local qc = (entry.quality and ITEM_QUALITY_COLORS[entry.quality]) or ITEM_QUALITY_COLORS[1]
        row.qualityBar:SetColorTexture(qc.r, qc.g, qc.b, 1)

        local iconTexture = entry.itemLink and GetItemIcon and GetItemIcon(entry.itemLink)
        row.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

        row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.015)
        row:Show()
    end

    for i = #list + 1, #historyRowPool do
        historyRowPool[i]:Hide()
    end

    historyUI.content:SetHeight(math.max(1, #list * HISTORY_ROW_HEIGHT))
end

------------------------------------------------------------
-- Mitglieder-Detailansicht (Inventar / Bank / Berufe)
------------------------------------------------------------

local function GetIconCell(index, parent)
    local cell = iconCellPool[index]
    if not cell then
        cell = CreateFrame("Frame", nil, parent)
        cell:SetSize(ICON_SIZE, ICON_SIZE)

        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetAllPoints()

        cell.border = cell:CreateTexture(nil, "OVERLAY")
        cell.border:SetAllPoints()
        cell.border:SetTexture("Interface\\Common\\WhiteIconFrame")

        cell.count = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        cell.count:SetPoint("BOTTOMRIGHT", 2, 0)

        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)

        iconCellPool[index] = cell
    end
    return cell
end

local function GetTextRow(index, parent)
    local row = textRowPool[index]
    if not row then
        row = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetJustifyH("LEFT")
        textRowPool[index] = row
    end
    row:SetWidth(MEMBER_ROW_WIDTH - 10)
    row:SetFontObject("GameFontHighlightSmall")
    return row
end

local function ClearIconCells()
    for _, cell in ipairs(iconCellPool) do
        cell:Hide()
        cell.itemID = nil
    end
end

local function ClearTextRows()
    for _, row in ipairs(textRowPool) do
        row:Hide()
        row:SetText("")
    end
end

-- Anklickbare Berufs-Kopfzeile (Dropdown-artig: Klick blendet die Rezeptliste
-- darunter ein/aus), getrennter Pool von den reinen Text-Zeilen, da Buttons
-- gebraucht werden.
local function GetProfessionRow(index, parent)
    local btn = profRowPool[index]
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn:SetSize(MEMBER_ROW_WIDTH - 10, 18)
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.text:SetPoint("LEFT", 0, 0)
        btn.text:SetJustifyH("LEFT")
        btn:SetScript("OnEnter", function() btn.text:SetTextColor(1, 0.82, 0) end)
        btn:SetScript("OnLeave", function() btn.text:SetTextColor(1, 1, 1) end)
        profRowPool[index] = btn
    end
    return btn
end

local function ClearProfessionRows()
    for _, btn in ipairs(profRowPool) do
        btn:Hide()
    end
end

-- Platziert ein fliessendes Icon-Grid unterhalb von anchorTo, gibt die Anzahl
-- benoetigter Zeilen zurueck (fuer die Cursor-Fortschaltung des Aufrufers).
local function PlaceIconGrid(parent, anchorTo, counts, yOffsetAfterAnchor)
    local sortedIDs = {}
    for itemID in pairs(counts) do table.insert(sortedIDs, itemID) end
    table.sort(sortedIDs)
    if #sortedIDs == 0 then return 0 end

    local perRow = math.max(1, math.floor(MEMBER_ROW_WIDTH / (ICON_SIZE + ICON_SPACING)))
    local col, rowIdx = 0, 0
    local rowStart

    for _, itemID in ipairs(sortedIDs) do
        nextIconIndex = nextIconIndex + 1
        local cell = GetIconCell(nextIconIndex, parent)
        cell.itemID = itemID
        local iconTexture = GetItemIcon and GetItemIcon(itemID)
        cell.icon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        local count = counts[itemID]
        cell.count:SetText((count and count > 1) and tostring(count) or "")
        cell:ClearAllPoints()
        if col == 0 then
            cell:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -(rowIdx * (ICON_SIZE + ICON_SPACING)) - yOffsetAfterAnchor)
            rowStart = cell
        else
            cell:SetPoint("LEFT", rowStart, "LEFT", col * (ICON_SIZE + ICON_SPACING), 0)
        end
        cell:Show()
        col = col + 1
        if col >= perRow then
            col = 0
            rowIdx = rowIdx + 1
        end
    end

    return rowIdx + (col > 0 and 1 or 0)
end

local function RenderMemberDetail(key)
    membersUI.currentDetailKey = key

    local display = key
    for _, m in ipairs(GroupFound.GetSortedList()) do
        if m.key == key then display = m.display break end
    end
    membersUI.nameText:SetText(display)

    local snap = GroupFound.GetMemberSnapshot(key)
    local updatedAt = GroupFound.GetSnapshotUpdatedAt(snap)
    if updatedAt then
        membersUI.standText:SetText(L.MEMBER_DETAIL_STAND_FMT:format(FormatRelativeTime(updatedAt)))
    else
        membersUI.standText:SetText(L.MEMBER_DETAIL_NO_DATA)
    end

    ClearIconCells()
    ClearTextRows()
    ClearProfessionRows()
    nextIconIndex, nextTextIndex, nextProfIndex = 0, 0, 0

    local content = membersUI.detailContent
    local cursor = membersUI.detailAnchor

    -- Gold
    nextTextIndex = nextTextIndex + 1
    local goldRow = GetTextRow(nextTextIndex, content)
    goldRow:SetFontObject("GameFontHighlightSmall")
    goldRow:ClearAllPoints()
    goldRow:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -8)
    if snap and snap.goldUpdatedAt then
        local gold = snap.gold or 0
        local goldText = GetCoinTextureString and GetCoinTextureString(gold) or tostring(gold)
        goldRow:SetText(L.GOLD_LABEL:format(goldText))
    else
        goldRow:SetText(L.GOLD_UNKNOWN)
    end
    goldRow:Show()
    cursor = goldRow

    -- Inventar
    nextTextIndex = nextTextIndex + 1
    local invHeader = GetTextRow(nextTextIndex, content)
    invHeader:SetFontObject("GameFontNormal")
    invHeader:ClearAllPoints()
    invHeader:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -12)
    invHeader:SetText(L.SECTION_INVENTORY)
    invHeader:Show()
    cursor = invHeader

    local bags = snap and snap.bags
    if bags and next(bags) then
        local rows = PlaceIconGrid(content, cursor, bags, 6)
        nextTextIndex = nextTextIndex + 1
        local spacer = GetTextRow(nextTextIndex, content)
        spacer:SetText("")
        spacer:ClearAllPoints()
        spacer:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -6 - rows * (ICON_SIZE + ICON_SPACING))
        spacer:Show()
        cursor = spacer
    else
        nextTextIndex = nextTextIndex + 1
        local emptyRow = GetTextRow(nextTextIndex, content)
        emptyRow:SetFontObject("GameFontDisableSmall")
        emptyRow:ClearAllPoints()
        emptyRow:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -6)
        emptyRow:SetText(L.SECTION_INVENTORY_EMPTY)
        emptyRow:Show()
        cursor = emptyRow
    end

    -- Bank
    nextTextIndex = nextTextIndex + 1
    local bankHeader = GetTextRow(nextTextIndex, content)
    bankHeader:SetFontObject("GameFontNormal")
    bankHeader:ClearAllPoints()
    bankHeader:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -14)
    bankHeader:SetText(L.SECTION_BANK)
    bankHeader:Show()
    cursor = bankHeader

    local bank = snap and snap.bank
    if bank and next(bank) then
        local rows = PlaceIconGrid(content, cursor, bank, 6)
        nextTextIndex = nextTextIndex + 1
        local spacer = GetTextRow(nextTextIndex, content)
        spacer:SetText("")
        spacer:ClearAllPoints()
        spacer:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -6 - rows * (ICON_SIZE + ICON_SPACING))
        spacer:Show()
        cursor = spacer
    else
        nextTextIndex = nextTextIndex + 1
        local emptyRow = GetTextRow(nextTextIndex, content)
        emptyRow:SetFontObject("GameFontDisableSmall")
        emptyRow:ClearAllPoints()
        emptyRow:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -6)
        emptyRow:SetText(L.SECTION_BANK_EMPTY)
        emptyRow:Show()
        cursor = emptyRow
    end

    -- Berufe + Rezepte (klappbar: Klick auf einen Beruf zeigt/versteckt seine Rezepte)
    nextTextIndex = nextTextIndex + 1
    local profHeader = GetTextRow(nextTextIndex, content)
    profHeader:SetFontObject("GameFontNormal")
    profHeader:ClearAllPoints()
    profHeader:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -14)
    profHeader:SetText(L.SECTION_PROFESSIONS)
    profHeader:Show()
    cursor = profHeader

    local professions = snap and snap.professions
    if professions and #professions > 0 then
        nextTextIndex = nextTextIndex + 1
        local profHint = GetTextRow(nextTextIndex, content)
        profHint:SetFontObject("GameFontDisableSmall")
        profHint:ClearAllPoints()
        profHint:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -4)
        profHint:SetText(L.SECTION_PROFESSIONS_HINT)
        profHint:Show()
        cursor = profHint

        for _, p in ipairs(professions) do
            local expandKey = key .. "|" .. p.name
            local isExpanded = expandedProfessions[expandKey]

            nextProfIndex = nextProfIndex + 1
            local profRow = GetProfessionRow(nextProfIndex, content)
            profRow:ClearAllPoints()
            profRow:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -8)
            profRow.text:SetText((isExpanded and "|cffffd100-|r " or "|cffffd100+|r ") .. L.PROFESSION_LEVEL_FMT:format(p.name, p.level, p.maxLevel))
            profRow:SetScript("OnClick", function()
                expandedProfessions[expandKey] = not expandedProfessions[expandKey]
                RenderMemberDetail(key)
            end)
            profRow:Show()
            cursor = profRow

            if isExpanded then
                local recipeIDs = snap.recipes and snap.recipes[p.name]
                local names = {}
                for _, spellID in ipairs(recipeIDs or {}) do
                    local spellName = GetSpellInfo(spellID)
                    if spellName then table.insert(names, spellName) end
                end

                nextTextIndex = nextTextIndex + 1
                local recipeRow = GetTextRow(nextTextIndex, content)
                recipeRow:SetFontObject("GameFontDisableSmall")
                recipeRow:SetWidth(MEMBER_ROW_WIDTH - 26)
                recipeRow:ClearAllPoints()
                recipeRow:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 10, -2)
                recipeRow:SetJustifyH("LEFT")
                recipeRow:SetText(#names > 0 and table.concat(names, ", ") or L.SECTION_RECIPES_EMPTY)
                recipeRow:Show()
                cursor = recipeRow
            end
        end
    else
        nextTextIndex = nextTextIndex + 1
        local emptyRow = GetTextRow(nextTextIndex, content)
        emptyRow:SetFontObject("GameFontDisableSmall")
        emptyRow:ClearAllPoints()
        emptyRow:SetPoint("TOPLEFT", cursor, "BOTTOMLEFT", 0, -6)
        emptyRow:SetText(L.SECTION_PROFESSIONS_EMPTY)
        emptyRow:Show()
        cursor = emptyRow
    end

    -- Grosszuegige Content-Hoehe: die ScrollFrame-Funktion braucht nur eine ausreichend
    -- grosse, keine pixelgenaue Hoehe (etwas ungenutzter Scrollbereich ist unschaedlich).
    content:SetHeight(1200)
end

function GroupFound.ShowMemberDetail(key)
    if not membersUI.listView then return end
    membersUI.listView:Hide()
    membersUI.detailView:Show()
    RenderMemberDetail(key)
end

function GroupFound.ShowMemberList()
    if not membersUI.listView then return end
    membersUI.detailView:Hide()
    membersUI.listView:Show()
    membersUI.currentDetailKey = nil
end

------------------------------------------------------------
-- Panel-Aufbau
------------------------------------------------------------

function GroupFound.BuildMembersPanel(parent)
    ------------------------------------------------------------
    -- Listen-Ansicht (Hinweis, Liste, Einladen, Status, Befehle)
    ------------------------------------------------------------
    local listView = CreateFrame("Frame", nil, parent)
    listView:SetAllPoints()
    membersUI.listView = listView

    local hint = listView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", 18, -10)
    hint:SetPoint("TOPRIGHT", -18, -10)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.HINT)

    CreateFlowDivider(listView, hint, 0, -12, 424)

    local listLabel = listView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -22)
    membersUI.listLabel = listLabel

    -- Inset bekommt eine feste Breite/Höhe statt eines zweiten, auf Vermutung
    -- basierenden absoluten Y-Ankers - bleibt so korrekt, egal wie viele Zeilen der
    -- (variabel lange) Hinweistext oben tatsächlich braucht.
    local inset = CreateFrame("Frame", nil, listView, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", -8, -8)
    inset:SetSize(408, 238)

    local scrollFrame = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(MEMBER_ROW_WIDTH, 1)
    scrollFrame:SetScrollChild(content)
    membersUI.content = content

    local emptyText = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER")
    emptyText:SetJustifyH("CENTER")
    emptyText:SetText(L.MEMBERS_EMPTY)
    membersUI.emptyText = emptyText

    -- Einladen. Leeres Feld + Klick = aktuelles Ziel direkt hinzufügen (wie frueher die
    -- Whitelist); mit Namen = Einladung senden, bei Annahme werden beide Seiten
    -- automatisch gegenseitig eingetragen.
    local inviteBox = CreateFrame("EditBox", "GroupFoundAddEditBox", listView, "InputBoxTemplate")
    inviteBox:SetSize(250, 20)
    inviteBox:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 8, -14)
    inviteBox:SetAutoFocus(false)

    local function DoAddOrInvite()
        local text = inviteBox:GetText()
        if text and trim(text) ~= "" then
            GroupFound.SendInvite(text)
            inviteBox:SetText("")
        else
            GroupFound.AddCurrentTarget()
        end
        inviteBox:ClearFocus()
    end
    inviteBox:SetScript("OnEnterPressed", DoAddOrInvite)

    local inviteBtn = CreateFrame("Button", nil, listView, "UIPanelButtonTemplate")
    inviteBtn:SetSize(96, 22)
    inviteBtn:SetPoint("LEFT", inviteBox, "RIGHT", 12, 0)
    inviteBtn:SetText(L.INVITE_BUTTON)
    inviteBtn:SetScript("OnClick", DoAddOrInvite)

    local inviteHint = listView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    inviteHint:SetPoint("TOPLEFT", inviteBox, "BOTTOMLEFT", 0, -6)
    inviteHint:SetWidth(340)
    inviteHint:SetJustifyH("LEFT")
    inviteHint:SetText(L.INVITE_HINT)

    local divider2 = CreateFlowDivider(listView, inviteHint, 0, -12, 384)

    local statusText = listView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", 6, -12)
    statusText:SetWidth(372)
    statusText:SetJustifyH("LEFT")
    statusText:SetTextColor(0.3, 1, 0.3)
    statusText:SetText(L.PROTECTION_ALWAYS_ON)

    local divider3 = CreateFlowDivider(listView, statusText, -6, -14, 384)

    local cmdLabel = listView:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdLabel:SetPoint("TOPLEFT", divider3, "BOTTOMLEFT", 6, -10)
    cmdLabel:SetText(L.CMD_LABEL)

    local cmdList = listView:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdList:SetPoint("TOPLEFT", cmdLabel, "BOTTOMLEFT", 0, -6)
    cmdList:SetWidth(384)
    cmdList:SetJustifyH("LEFT")
    cmdList:SetSpacing(3)
    cmdList:SetText(
        L.CMD_TOGGLE .. "\n" ..
        L.CMD_ADD .. "\n" ..
        L.CMD_ADD_TARGET .. "\n" ..
        L.CMD_REMOVE .. "\n" ..
        L.CMD_LIST .. "\n" ..
        L.CMD_INVITE .. "\n" ..
        L.CMD_GROUP
    )

    ------------------------------------------------------------
    -- Detail-Ansicht
    ------------------------------------------------------------
    local detailView = CreateFrame("Frame", nil, parent)
    detailView:SetAllPoints()
    detailView:Hide()
    membersUI.detailView = detailView

    local backBtn = CreateFrame("Button", nil, detailView, "UIPanelButtonTemplate")
    backBtn:SetSize(90, 20)
    backBtn:SetPoint("TOPLEFT", 18, -8)
    backBtn:SetText(L.MEMBER_DETAIL_BACK)
    backBtn:SetScript("OnClick", function() GroupFound.ShowMemberList() end)

    local nameText = detailView:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameText:SetPoint("LEFT", backBtn, "RIGHT", 12, 0)
    membersUI.nameText = nameText

    local standText = detailView:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    standText:SetPoint("TOPLEFT", backBtn, "BOTTOMLEFT", 0, -8)
    membersUI.standText = standText

    local detailInset = CreateFrame("Frame", nil, detailView, "InsetFrameTemplate")
    detailInset:SetPoint("TOPLEFT", standText, "BOTTOMLEFT", -8, -10)
    detailInset:SetPoint("BOTTOMRIGHT", detailView, "BOTTOMRIGHT", -18, 0)

    local detailScroll = CreateFrame("ScrollFrame", nil, detailInset, "UIPanelScrollFrameTemplate")
    detailScroll:SetPoint("TOPLEFT", 6, -6)
    detailScroll:SetPoint("BOTTOMRIGHT", -28, 6)

    local detailContent = CreateFrame("Frame", nil, detailScroll)
    detailContent:SetSize(MEMBER_ROW_WIDTH, 1)
    detailScroll:SetScrollChild(detailContent)
    membersUI.detailContent = detailContent

    local detailAnchor = CreateFrame("Frame", nil, detailContent)
    detailAnchor:SetSize(1, 1)
    detailAnchor:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 0, 0)
    membersUI.detailAnchor = detailAnchor
end

function GroupFound.BuildHistoryPanel(parent)
    local inset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", 16, -10)
    inset:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -16, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(HISTORY_ROW_WIDTH, 1)
    scrollFrame:SetScrollChild(content)
    historyUI.content = content

    local emptyText = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("CENTER")
    emptyText:SetJustifyH("CENTER")
    historyUI.emptyText = emptyText
end

function GroupFound.RefreshGroupUI()
    RefreshMemberList()
    RefreshHistoryList()
    if membersUI.detailView and membersUI.detailView:IsShown() and membersUI.currentDetailKey then
        RenderMemberDetail(membersUI.currentDetailKey)
    end
end
