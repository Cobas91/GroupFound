-- GroupFound Comm
-- Fund-Historie, Inventar/Bank/Berufe-Snapshots und Loot-Erkennung, geteilt mit allen
-- Spielern auf der Whitelist (Core.lua). Die Whitelist ist die einzige Mitgliederliste:
-- wer auf ihr steht, gehoert zur Gruppe. Kommunikation ausschliesslich ueber WHISPER-
-- Addon-Messages zwischen GroupFound-Instanzen, es gibt keinen Server - jeder Client
-- haelt seinen eigenen vollstaendigen Stand und gleicht ihn periodisch mit allen
-- Whitelist-Eintraegen ab (Best-Effort, kein Zustellnachweis moeglich).

GroupFound = GroupFound or {}
local ADDON_NAME = "GroupFound"
local L = GroupFound.L

local COMM_PREFIX = "GroupFound"
local SEP = "\1"
local HISTORY_CAP = 300
local GOSSIP_INTERVAL = 180
local GOSSIP_ITEM_BATCH = 20
local PENDING_INVITE_TTL = 60
local SNAP_CHUNK_ENTRIES = 20
local SNAP_BUFFER_TTL = 120
local ONLINE_WINDOW = 300

------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

local function GetSelfFullName()
    local name = UnitName("player")
    local realm = GetRealmName()
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function GroupFound.GetSelfFullName()
    return GetSelfFullName()
end

local function NormalizeKey(name)
    return trim(name or ""):lower()
end

-- Findet den Whitelist-Key zu einem Absender aus CHAT_MSG_ADDON. Der Absender kommt je
-- nach Realm-Situation als bloßer Name oder als "Name-Realm" an - gleiche
-- Bare-Name-dann-kombiniert-Logik wie GroupFound.IsWhitelisted (Core.lua:108-121), gibt
-- aber den passenden Key statt nur eines Bool zurück (fuer konsistente Snapshot-Keys).
local function FindWhitelistKey(sender)
    if not GroupFoundDB or not sender or sender == "" then return nil end
    local name, realm = strsplit("-", sender, 2)
    local lname = (name or sender):lower()
    if GroupFoundDB.whitelist[lname] then return lname end
    if realm and realm ~= "" then
        local combined = (name .. "-" .. realm):lower()
        if GroupFoundDB.whitelist[combined] then return combined end
    end
    return nil
end

local function IsSenderWhitelisted(sender)
    return FindWhitelistKey(sender) ~= nil
end

-- Gleiche Bare-Name-dann-kombiniert-Logik wie FindWhitelistKey, aber gegen
-- pendingInvites: der Name, den man beim Einladen eingetippt hat (z.B. "Bob" ohne
-- Realm), muss auch dann wiedergefunden werden, wenn die ACC/DEC-Antwort mit
-- Realm-Suffix ankommt ("Bob-Realm") - sonst bleibt die Einladung serverseitig offen
-- und der Erfinder wird nie zur eigenen Liste hinzugefügt.
local function FindPendingKey(sender)
    if not GroupFoundCharDB or not sender or sender == "" then return nil end
    local name, realm = strsplit("-", sender, 2)
    local lname = (name or sender):lower()
    if GroupFoundCharDB.pendingInvites[lname] then return lname end
    if realm and realm ~= "" then
        local combined = (name .. "-" .. realm):lower()
        if GroupFoundCharDB.pendingInvites[combined] then return combined end
    end
    return nil
end

local lastSeenAt = {}

local function TouchLastSeen(sender)
    local key = FindWhitelistKey(sender)
    if key then
        lastSeenAt[key] = time()
    end
end

-- Naeherungswert für "online": true wenn seit der letzten empfangenen Gossip-/Item-/
-- Snapshot-Nachricht dieses Mitglieds weniger als 5 Minuten vergangen sind. Kein echter
-- Presence-Check (für beliebige Spielernamen nicht zuverlässig möglich), nicht
-- persistiert (setzt bei jedem Login neu an).
function GroupFound.IsMemberRecentlyActive(key)
    local seen = lastSeenAt[key]
    if not seen then return false end
    return (time() - seen) < ONLINE_WINDOW
end

function GroupFound.GetMemberLastSeen(key)
    return lastSeenAt[key]
end

local function SendComm(message, target)
    if not target or target == "" then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, "WHISPER", target)
    elseif SendAddonMessage then
        SendAddonMessage(COMM_PREFIX, message, "WHISPER", target)
    end
end

local function RegisterComm()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
    end
end

local function GetWhitelistTargets()
    local targets = {}
    for _, entry in ipairs(GroupFound.GetSortedList()) do
        table.insert(targets, entry.display)
    end
    return targets
end

------------------------------------------------------------
-- SavedVariablesPerCharacter / DB
------------------------------------------------------------

function GroupFound.InitCharDB()
    GroupFoundCharDB = GroupFoundCharDB or {}
    GroupFoundCharDB.history = GroupFoundCharDB.history or {}
    GroupFoundCharDB.nextLocalId = GroupFoundCharDB.nextLocalId or 1
    GroupFoundCharDB.snapshots = GroupFoundCharDB.snapshots or {}
    GroupFoundCharDB.pendingInvites = GroupFoundCharDB.pendingInvites or {}
end

------------------------------------------------------------
-- Fund-Historie
------------------------------------------------------------

function GroupFound.PruneHistory()
    if not GroupFoundCharDB or not GroupFoundCharDB.history then return end
    local list = {}
    for id, entry in pairs(GroupFoundCharDB.history) do
        table.insert(list, { id = id, ts = entry.ts or 0 })
    end
    if #list <= HISTORY_CAP then return end
    table.sort(list, function(a, b) return a.ts > b.ts end)
    for i = HISTORY_CAP + 1, #list do
        GroupFoundCharDB.history[list[i].id] = nil
    end
end

function GroupFound.MergeItem(id, finder, itemLink, quality, count, ts)
    if not GroupFoundCharDB then return end
    if not id or id == "" or GroupFoundCharDB.history[id] then return end
    GroupFoundCharDB.history[id] = {
        finder = finder,
        itemLink = itemLink,
        quality = quality,
        count = count or 1,
        ts = ts or time(),
    }
    GroupFound.PruneHistory()
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

function GroupFound.GetSortedHistory()
    local list = {}
    if not GroupFoundCharDB or not GroupFoundCharDB.history then return list end
    for id, entry in pairs(GroupFoundCharDB.history) do
        local e = { id = id }
        for k, v in pairs(entry) do e[k] = v end
        table.insert(list, e)
    end
    table.sort(list, function(a, b) return (a.ts or 0) > (b.ts or 0) end)
    return list
end

function GroupFound.RecordOwnFind(itemLink, quality, count)
    if not GroupFoundCharDB then return end

    local selfName = GetSelfFullName()
    local id = NormalizeKey(selfName) .. "#" .. GroupFoundCharDB.nextLocalId
    GroupFoundCharDB.nextLocalId = GroupFoundCharDB.nextLocalId + 1

    local entry = { finder = selfName, itemLink = itemLink, quality = quality, count = count or 1, ts = time() }
    GroupFoundCharDB.history[id] = entry
    GroupFound.PruneHistory()
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end

    local message = table.concat(
        { "ITEM", id, entry.finder, entry.itemLink, tostring(entry.quality), tostring(entry.count), tostring(entry.ts) },
        SEP
    )
    for _, target in ipairs(GetWhitelistTargets()) do
        SendComm(message, target)
    end
end

------------------------------------------------------------
-- Einladen (fügt bei Annahme beide Seiten gegenseitig zur Whitelist hinzu)
------------------------------------------------------------

function GroupFound.SendInvite(rawName)
    local raw = trim(rawName)
    if raw == "" then return end
    local key = raw:lower()

    if key == NormalizeKey(GetSelfFullName()) then
        GroupFound.Print(L.MSG_CANNOT_INVITE_SELF)
        return
    end
    if GroupFoundDB.whitelist[key] then
        GroupFound.Print(L.MSG_ALREADY_LINKED:format(raw))
        return
    end

    GroupFoundCharDB.pendingInvites[key] = time() + PENDING_INVITE_TTL
    SendComm("INV", raw)
    GroupFound.Print(L.MSG_INVITE_SENT:format(raw))
end

StaticPopupDialogs["GROUPFOUND_INVITE"] = {
    text = "%s",
    button1 = L.POPUP_ACCEPT,
    button2 = L.POPUP_DECLINE,
    OnAccept = function(self, data)
        GroupFound.AddName(data.sender)
        SendComm("ACC", data.sender)
        GroupFound.GossipPush()
        if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
    end,
    OnCancel = function(self, data)
        SendComm("DEC", data.sender)
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

function GroupFound.ShowInvitePopup(sender)
    local text = L.POPUP_INVITE_TEXT:format(sender)
    StaticPopup_Show("GROUPFOUND_INVITE", text, nil, { sender = sender })
end

------------------------------------------------------------
-- Inventar-, Bank- und Berufs-Snapshots
------------------------------------------------------------

-- Kompat-Shims analog zum bestehenden Muster in Core.lua (CloseAH) fuer altes/neues
-- Container-API. Exakte Legacy-Fallback-Signaturen vor Release gegen den aktuellen
-- Classic-Era-Client verifizieren.
local function GetBagNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots(bag)
end

local function GetBagSlotItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID then
            return info.itemID, info.stackCount or 1
        end
        return nil
    end
    local itemLink = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not itemLink then return nil end
    local _, count = GetContainerItemInfo(bag, slot)
    local itemID = GetItemInfoInstant(itemLink)
    if not itemID then return nil end
    return itemID, count or 1
end

local function EnsureSnapshot(key)
    GroupFoundCharDB.snapshots[key] = GroupFoundCharDB.snapshots[key] or {}
    return GroupFoundCharDB.snapshots[key]
end

function GroupFound.CaptureBags()
    if not GroupFoundCharDB then return end
    local counts = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = GetBagNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID, count = GetBagSlotItem(bag, slot)
            if itemID then
                counts[itemID] = (counts[itemID] or 0) + count
            end
        end
    end
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.bags = counts
    snap.bagsUpdatedAt = time()
    GroupFound.PushSnapshotKind("BAGS")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

function GroupFound.CaptureBank()
    if not GroupFoundCharDB then return end
    local counts = {}
    local bankBags = { -1 }
    for i = 1, (NUM_BANKBAGSLOTS or 7) do
        table.insert(bankBags, 4 + i) -- Bank-Taschen liegen ab Bag-ID 5
    end
    for _, bag in ipairs(bankBags) do
        local slots = GetBagNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID, count = GetBagSlotItem(bag, slot)
            if itemID then
                counts[itemID] = (counts[itemID] or 0) + count
            end
        end
    end
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.bank = counts
    snap.bankUpdatedAt = time()
    GroupFound.PushSnapshotKind("BANK")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

-- Rezepte werden ueber die Spellbook-Tabs ermittelt (GetNumSpellTabs/GetSpellTabInfo),
-- nicht ueber GetProfessionInfo's spellOffset/numAbilities - letzteres zeigte sich beim
-- Live-Test als unzuverlaessig (Rezepte fehlten). Der Tab-Name eines Spellbook-Tabs
-- entspricht dem Berufsnamen; das ist der etablierte, robuste Ansatz.
local function CaptureProfessionsImpl()
    local professions = {}
    local recipes = {}

    -- pairs() statt ipairs(): GetProfessions() kann Luecken in der Mitte liefern
    -- (z.B. keine Erstberufe, aber Kochen) - ipairs wuerde beim ersten nil abbrechen.
    local profIndices = { GetProfessions() }
    local profNames = {}
    for _, index in pairs(profIndices) do
        if index then
            local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(index)
            if name then
                table.insert(professions, { name = name, level = skillLevel or 0, maxLevel = maxSkillLevel or 0 })
                profNames[name] = true
            end
        end
    end

    if next(profNames) and GetNumSpellTabs and GetSpellTabInfo then
        local numTabs = GetNumSpellTabs() or 0
        for tabIndex = 1, numTabs do
            local tabName, _, offset, numSpells = GetSpellTabInfo(tabIndex)
            if tabName and profNames[tabName] and numSpells and numSpells > 0 then
                local spellIDs = {}
                for i = offset + 1, offset + numSpells do
                    local spellName
                    if GetSpellBookItemName then
                        spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                    end
                    if spellName then
                        local resolvedID = select(7, GetSpellInfo(spellName))
                        if resolvedID then table.insert(spellIDs, resolvedID) end
                    end
                end
                if #spellIDs > 0 then
                    recipes[tabName] = spellIDs
                end
            end
        end
    end

    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.professions = professions
    snap.profUpdatedAt = time()
    snap.recipes = recipes
    snap.recipesUpdatedAt = time()
    GroupFound.PushSnapshotKind("PROF")
    GroupFound.PushSnapshotKind("RECIPES")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

function GroupFound.CaptureProfessions()
    if not GroupFoundCharDB then return end
    local ok, err = pcall(CaptureProfessionsImpl)
    if not ok then
        GroupFound.Print("CaptureProfessions error: " .. tostring(err))
    end
end

function GroupFound.CaptureGold()
    if not GroupFoundCharDB then return end
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.gold = GetMoney and GetMoney() or 0
    snap.goldUpdatedAt = time()
    GroupFound.PushSnapshotKind("GOLD")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

local captureThrottle = {}

local function ThrottledCapture(kind, fn)
    if captureThrottle[kind] then return end
    captureThrottle[kind] = true
    C_Timer.After(3, function()
        captureThrottle[kind] = nil
        fn()
    end)
end

------------------------------------------------------------
-- Snapshot-Payloads (Versand/Empfang, chunked)
------------------------------------------------------------

local function BuildCountsPayload(counts)
    local parts = {}
    for itemID, count in pairs(counts or {}) do
        table.insert(parts, itemID .. ":" .. count)
    end
    return table.concat(parts, ";")
end

local function ParseCountsPayload(payload)
    local counts = {}
    for entry in (payload or ""):gmatch("[^;]+") do
        local itemID, count = entry:match("^(%d+):(%d+)$")
        if itemID then
            counts[tonumber(itemID)] = tonumber(count)
        end
    end
    return counts
end

local function BuildProfessionsPayload(professions)
    local parts = {}
    for _, p in ipairs(professions or {}) do
        table.insert(parts, p.name .. ":" .. p.level .. ":" .. p.maxLevel)
    end
    return table.concat(parts, ";")
end

local function ParseProfessionsPayload(payload)
    local list = {}
    for entry in (payload or ""):gmatch("[^;]+") do
        local name, level, maxLevel = entry:match("^(.-):(%d+):(%d+)$")
        if name then
            table.insert(list, { name = name, level = tonumber(level), maxLevel = tonumber(maxLevel) })
        end
    end
    return list
end

local function BuildRecipesPayload(recipes)
    local parts = {}
    for profName, spellIDs in pairs(recipes or {}) do
        table.insert(parts, profName .. ":" .. table.concat(spellIDs, ","))
    end
    return table.concat(parts, ";")
end

local function ParseGoldPayload(payload)
    return tonumber(payload) or 0
end

local function ParseRecipesPayload(payload)
    local map = {}
    for entry in (payload or ""):gmatch("[^;]+") do
        local name, idsCSV = entry:match("^(.-):(.*)$")
        if name and name ~= "" then
            local ids = {}
            for id in idsCSV:gmatch("%d+") do
                table.insert(ids, tonumber(id))
            end
            map[name] = ids
        end
    end
    return map
end

function GroupFound.SendSnapshotChunks(kind, payload, updatedAt, targets)
    if not targets or #targets == 0 or not updatedAt then return end

    local entries = {}
    for entry in (payload .. ";"):gmatch("(.-);") do
        if entry ~= "" then table.insert(entries, entry) end
    end

    local chunks = {}
    local current = {}
    for _, entry in ipairs(entries) do
        table.insert(current, entry)
        if #current >= SNAP_CHUNK_ENTRIES then
            table.insert(chunks, table.concat(current, ";"))
            current = {}
        end
    end
    if #current > 0 or #chunks == 0 then
        table.insert(chunks, table.concat(current, ";"))
    end

    for idx, chunkPayload in ipairs(chunks) do
        local msg = table.concat({ "SNAP", kind, tostring(updatedAt), tostring(idx), tostring(#chunks), chunkPayload }, SEP)
        for _, target in ipairs(targets) do
            SendComm(msg, target)
        end
    end
end

function GroupFound.PushSnapshotKind(kind)
    if not GroupFoundCharDB then return end
    local selfKey = NormalizeKey(GetSelfFullName())
    local snap = GroupFoundCharDB.snapshots[selfKey]
    if not snap then return end

    local targets = GetWhitelistTargets()
    if #targets == 0 then return end

    if kind == "BAGS" and snap.bagsUpdatedAt then
        GroupFound.SendSnapshotChunks("BAGS", BuildCountsPayload(snap.bags), snap.bagsUpdatedAt, targets)
    elseif kind == "BANK" and snap.bankUpdatedAt then
        GroupFound.SendSnapshotChunks("BANK", BuildCountsPayload(snap.bank), snap.bankUpdatedAt, targets)
    elseif kind == "PROF" and snap.profUpdatedAt then
        GroupFound.SendSnapshotChunks("PROF", BuildProfessionsPayload(snap.professions), snap.profUpdatedAt, targets)
    elseif kind == "RECIPES" and snap.recipesUpdatedAt then
        GroupFound.SendSnapshotChunks("RECIPES", BuildRecipesPayload(snap.recipes), snap.recipesUpdatedAt, targets)
    elseif kind == "GOLD" and snap.goldUpdatedAt then
        GroupFound.SendSnapshotChunks("GOLD", tostring(snap.gold or 0), snap.goldUpdatedAt, targets)
    end
end

function GroupFound.PushSnapshots(targets)
    if not GroupFoundCharDB or not targets or #targets == 0 then return end
    local snap = GroupFoundCharDB.snapshots[NormalizeKey(GetSelfFullName())]
    if not snap then return end

    if snap.bagsUpdatedAt then
        GroupFound.SendSnapshotChunks("BAGS", BuildCountsPayload(snap.bags), snap.bagsUpdatedAt, targets)
    end
    if snap.bankUpdatedAt then
        GroupFound.SendSnapshotChunks("BANK", BuildCountsPayload(snap.bank), snap.bankUpdatedAt, targets)
    end
    if snap.profUpdatedAt then
        GroupFound.SendSnapshotChunks("PROF", BuildProfessionsPayload(snap.professions), snap.profUpdatedAt, targets)
    end
    if snap.recipesUpdatedAt then
        GroupFound.SendSnapshotChunks("RECIPES", BuildRecipesPayload(snap.recipes), snap.recipesUpdatedAt, targets)
    end
    if snap.goldUpdatedAt then
        GroupFound.SendSnapshotChunks("GOLD", tostring(snap.gold or 0), snap.goldUpdatedAt, targets)
    end
end

local pendingSnapshotChunks = {}

local function CleanupStaleSnapshotBuffers()
    local now = time()
    for key, buffer in pairs(pendingSnapshotChunks) do
        if now - buffer.receivedAt > SNAP_BUFFER_TTL then
            pendingSnapshotChunks[key] = nil
        end
    end
end

local function OnSnapChunkReceived(sender, kind, updatedAt, chunkIdx, totalChunks, payload)
    if not kind or not updatedAt or not chunkIdx or not totalChunks then return end

    CleanupStaleSnapshotBuffers()

    local bufferKey = sender .. "|" .. kind .. "|" .. updatedAt
    local buffer = pendingSnapshotChunks[bufferKey]
    if not buffer then
        buffer = { chunks = {}, total = totalChunks, receivedAt = time() }
        pendingSnapshotChunks[bufferKey] = buffer
    end
    buffer.chunks[chunkIdx] = payload

    for i = 1, buffer.total do
        if not buffer.chunks[i] then return end -- noch nicht vollständig
    end
    pendingSnapshotChunks[bufferKey] = nil
    local fullPayload = table.concat(buffer.chunks, ";")

    local memberKey = FindWhitelistKey(sender)
    if not memberKey then return end
    local snap = EnsureSnapshot(memberKey)

    if kind == "BAGS" and updatedAt > (snap.bagsUpdatedAt or 0) then
        snap.bags = ParseCountsPayload(fullPayload)
        snap.bagsUpdatedAt = updatedAt
    elseif kind == "BANK" and updatedAt > (snap.bankUpdatedAt or 0) then
        snap.bank = ParseCountsPayload(fullPayload)
        snap.bankUpdatedAt = updatedAt
    elseif kind == "PROF" and updatedAt > (snap.profUpdatedAt or 0) then
        snap.professions = ParseProfessionsPayload(fullPayload)
        snap.profUpdatedAt = updatedAt
    elseif kind == "RECIPES" and updatedAt > (snap.recipesUpdatedAt or 0) then
        snap.recipes = ParseRecipesPayload(fullPayload)
        snap.recipesUpdatedAt = updatedAt
    elseif kind == "GOLD" and updatedAt > (snap.goldUpdatedAt or 0) then
        snap.gold = ParseGoldPayload(fullPayload)
        snap.goldUpdatedAt = updatedAt
    end

    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

function GroupFound.GetMemberSnapshot(memberKey)
    if not GroupFoundCharDB or not GroupFoundCharDB.snapshots then return nil end
    return GroupFoundCharDB.snapshots[memberKey]
end

function GroupFound.GetSnapshotUpdatedAt(snap)
    if not snap then return nil end
    local latest = nil
    for _, field in ipairs({ "bagsUpdatedAt", "bankUpdatedAt", "profUpdatedAt", "recipesUpdatedAt", "goldUpdatedAt" }) do
        if snap[field] and (not latest or snap[field] > latest) then
            latest = snap[field]
        end
    end
    return latest
end

------------------------------------------------------------
-- Laufender Abgleich (Gossip)
------------------------------------------------------------

function GroupFound.GossipPush(explicitTargets)
    local targets = explicitTargets or GetWhitelistTargets()
    if #targets == 0 then return end

    local historyList = GroupFound.GetSortedHistory()
    for i = 1, math.min(GOSSIP_ITEM_BATCH, #historyList) do
        local e = historyList[i]
        local itemMsg = table.concat(
            { "ITEM", e.id, e.finder, e.itemLink, tostring(e.quality), tostring(e.count), tostring(e.ts) },
            SEP
        )
        for _, target in ipairs(targets) do
            SendComm(itemMsg, target)
        end
    end

    GroupFound.PushSnapshots(targets)
end

------------------------------------------------------------
-- Locale-unabhängige Loot-Erkennung
------------------------------------------------------------

local function BuildLootPattern(template)
    local pattern = template:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)")
    pattern = pattern:gsub("%%%%d", "(%%d+)")
    return "^" .. pattern .. "$"
end

local PATTERN_SELF, PATTERN_SELF_MULTIPLE

local function EnsureLootPatterns()
    if PATTERN_SELF then return end
    PATTERN_SELF = BuildLootPattern(LOOT_ITEM_SELF)
    PATTERN_SELF_MULTIPLE = BuildLootPattern(LOOT_ITEM_SELF_MULTIPLE)
end

-- Unter Level 60 zaehlen Gruene+ (Uncommon) als Fund, ab Level 60 nur noch Blau+ (Rare) -
-- gruene Items werden fuer einen frischen Twink noch als nennenswerter Fund empfunden,
-- fuer einen Level-60-Charakter nicht mehr.
local function GetFindQualityThreshold()
    local level = UnitLevel("player") or 1
    if level >= 60 then
        return ITEM_QUALITY_RARE or 3
    end
    return ITEM_QUALITY_UNCOMMON or 2
end

local function HandleLootMessage(msg)
    if not GroupFoundDB or not next(GroupFoundDB.whitelist) then return end
    EnsureLootPatterns()

    local itemLink = msg:match(PATTERN_SELF)
    local count = 1
    if not itemLink then
        local link, cnt = msg:match(PATTERN_SELF_MULTIPLE)
        itemLink, count = link, tonumber(cnt) or 1
    end
    if not itemLink then return end -- z.B. LOOT_ITEM_CREATED_SELF matcht keins der beiden -> ignoriert

    local _, _, quality = GetItemInfo(itemLink)
    if not quality or quality < GetFindQualityThreshold() then return end

    GroupFound.RecordOwnFind(itemLink, quality, count)
end

------------------------------------------------------------
-- Addon-Message-Dispatcher
------------------------------------------------------------

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX or channel ~= "WHISPER" then return end
    if not sender or not message then return end

    local typ, rest = message:match("^(%a+)" .. SEP .. "?(.*)$")
    if not typ then return end

    if typ == "INV" then
        GroupFound.ShowInvitePopup(sender)
    elseif typ == "ACC" then
        local key = FindPendingKey(sender)
        if key then
            GroupFoundCharDB.pendingInvites[key] = nil
            GroupFound.AddName(sender)
            GroupFound.Print(L.MSG_INVITE_ACCEPTED:format(sender))
            GroupFound.GossipPush()
            if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
        end
    elseif typ == "DEC" then
        local key = FindPendingKey(sender)
        if key then
            GroupFoundCharDB.pendingInvites[key] = nil
            GroupFound.Print(L.MSG_INVITE_DECLINED:format(sender))
        end
    elseif typ == "ITEM" then
        if IsSenderWhitelisted(sender) then
            TouchLastSeen(sender)
            local id, finder, itemLink, quality, count, ts = strsplit(SEP, rest, 6)
            GroupFound.MergeItem(id, finder, itemLink, tonumber(quality), tonumber(count), tonumber(ts))
        end
    elseif typ == "SNAP" then
        if IsSenderWhitelisted(sender) then
            TouchLastSeen(sender)
            local kind, updatedAt, chunkIdx, totalChunks, payload = strsplit(SEP, rest, 5)
            OnSnapChunkReceived(sender, kind, tonumber(updatedAt), tonumber(chunkIdx), tonumber(totalChunks), payload or "")
        end
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local commEventFrame = CreateFrame("Frame")
commEventFrame:RegisterEvent("ADDON_LOADED")
commEventFrame:RegisterEvent("PLAYER_LOGIN")
commEventFrame:RegisterEvent("CHAT_MSG_ADDON")
commEventFrame:RegisterEvent("CHAT_MSG_LOOT")
commEventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
commEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
commEventFrame:RegisterEvent("BANKFRAME_CLOSED")
commEventFrame:RegisterEvent("SKILL_LINES_CHANGED")
commEventFrame:RegisterEvent("SPELLS_CHANGED")
commEventFrame:RegisterEvent("PLAYER_MONEY")

commEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            GroupFound.InitCharDB()
            RegisterComm()
        end
    elseif event == "PLAYER_LOGIN" then
        GroupFound.InitCharDB()
        C_Timer.After(2, function()
            GroupFound.CaptureProfessions()
            GroupFound.CaptureGold()
            GroupFound.GossipPush()
        end)
        C_Timer.NewTicker(GOSSIP_INTERVAL, function() GroupFound.GossipPush() end)
    elseif event == "PLAYER_MONEY" then
        ThrottledCapture("gold", GroupFound.CaptureGold)
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "CHAT_MSG_LOOT" then
        HandleLootMessage(...)
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Blizzard hat Bag-Update-Bursts hier bereits zu einem Event gebündelt, kein
        -- zusätzliches Debouncing nötig.
        GroupFound.CaptureBags()
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        ThrottledCapture("bank", GroupFound.CaptureBank)
    elseif event == "BANKFRAME_CLOSED" then
        GroupFound.CaptureBank()
    elseif event == "SKILL_LINES_CHANGED" or event == "SPELLS_CHANGED" then
        ThrottledCapture("professions", GroupFound.CaptureProfessions)
    end
end)
