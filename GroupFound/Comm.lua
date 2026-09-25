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
local SNAP_PAYLOAD_BYTES = 210
local SNAP_BUFFER_TTL = 120
local ONLINE_WINDOW = 300
local MAX_COMM_BYTES = 255
local MAX_SNAP_CHUNKS = 100
local MAX_ITEM_LINK_BYTES = 1024

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
    return GroupFound.NormalizeNameKey(name)
end

local function LocalRealmKey()
    return (GetRealmName() or ""):gsub("%s+", ""):lower()
end

local function IsSameCharacter(a, b)
    local aName, aRealm = strsplit("-", NormalizeKey(a), 2)
    local bName, bRealm = strsplit("-", NormalizeKey(b), 2)
    if aName ~= bName then return false end
    aRealm = aRealm and aRealm:gsub("%s+", "") or LocalRealmKey()
    bRealm = bRealm and bRealm:gsub("%s+", "") or LocalRealmKey()
    return aRealm == bRealm
end

-- Findet den Whitelist-Key zu einem Absender aus CHAT_MSG_ADDON. Der Absender kommt je
-- nach Realm-Situation als bloßer Name oder als "Name-Realm" an - gleiche
-- Bare-Name-dann-kombiniert-Logik wie GroupFound.IsWhitelisted (Core.lua:108-121), gibt
-- aber den passenden Key statt nur eines Bool zurück (fuer konsistente Snapshot-Keys).
local function FindWhitelistKey(sender)
    if not GroupFoundDB or not sender or sender == "" then return nil end
    local name, realm = strsplit("-", sender, 2)
    local lname = NormalizeKey(name or sender)
    if GroupFoundDB.whitelist[lname] then return lname end
    if not realm or realm == "" then realm = GetRealmName() end
    local combined = NormalizeKey(name .. "-" .. realm)
    if GroupFoundDB.whitelist[combined] then return combined end
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
    for key in pairs(GroupFoundCharDB.pendingInvites) do
        if IsSameCharacter(key, sender) then return key end
    end
    return nil
end

local lastSeenAt = {}
local memberVersions = {}

local function GetAddonVersion()
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMeta and getMeta(ADDON_NAME, "Version") or "?"
end

function GroupFound.GetMemberVersion(key)
    return memberVersions[key]
end

-- Vergleicht "2.0.10" mit "2.0.9" numerisch je Segment; true, wenn a neuer ist als b.
function GroupFound.IsNewerVersion(a, b)
    local function parts(v)
        local list = {}
        for n in tostring(v or ""):gmatch("%d+") do table.insert(list, tonumber(n)) end
        return list
    end
    local pa, pb = parts(a), parts(b)
    if #pa == 0 or #pb == 0 then return false end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

-- Es gibt keinen Server, den man nach der neuesten Version fragen koennte: neuere
-- Versionen werden daran erkannt, dass ein Gruppenmitglied sie meldet (HI-Nachricht).
local notifiedVersion
local function NotifyIfNewer(version)
    local own = GetAddonVersion()
    if version ~= notifiedVersion and GroupFound.IsNewerVersion(version, own)
            and (not notifiedVersion or GroupFound.IsNewerVersion(version, notifiedVersion)) then
        notifiedVersion = version
        GroupFound.Print(L.MSG_NEW_VERSION:format(version, own))
    end
end

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

-- Zweiter Rueckgabewert: true, wenn der Client die Nachricht wegen Throttling abgelehnt hat
-- (Enum.SendAddonMessageResult.AddonMessageThrottle/ChannelThrottle = 3/4) - dann lohnt
-- ein spaeterer Versuch, bei allen anderen Fehlern nicht.
local function TrySendComm(message, target)
    if not target or target == "" or #message > MAX_COMM_BYTES then return false end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local result = C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, "WHISPER", target)
        if result == nil or result == 0 or result == true then return true end
        return false, (result == 3 or result == 4)
    elseif SendAddonMessage then
        return SendAddonMessage(COMM_PREFIX, message, "WHISPER", target) ~= false
    end
    return false
end

local function SendComm(message, target)
    return (TrySendComm(message, target))
end

-- Gedrosselte Sende-Warteschlange fuer Massen-Nachrichten (Snapshots, Gossip, Funde).
-- Blizzard verwirft Addon-Nachrichten nach einem kleinen Burst still (Throttle-Ergebnis),
-- ein Schwall aus Bag-/Rezept-Chunks liess so Gold und Berufe nie ankommen. Niedrigere
-- prio wird zuerst gesendet; bei Throttling wird spaeter erneut versucht.
local SEND_INTERVAL = 0.25
local RETRY_INTERVAL = 1.5
local MAX_SEND_ATTEMPTS = 30
local OUTBOX_CAP = 600

local outbox = {}
local pumpScheduled = false

local SchedulePump

local function PumpOutbox()
    pumpScheduled = false
    local bestIdx
    for i, item in ipairs(outbox) do
        if not bestIdx or item.prio < outbox[bestIdx].prio then bestIdx = i end
    end
    if not bestIdx then return end

    local item = outbox[bestIdx]
    local ok, throttled = TrySendComm(item.message, item.target)
    local delay = SEND_INTERVAL
    if ok then
        table.remove(outbox, bestIdx)
    else
        item.attempts = item.attempts + 1
        if throttled and item.attempts < MAX_SEND_ATTEMPTS then
            delay = RETRY_INTERVAL
        else
            table.remove(outbox, bestIdx)
        end
    end
    if #outbox > 0 then SchedulePump(delay) end
end

SchedulePump = function(delay)
    if pumpScheduled then return end
    pumpScheduled = true
    C_Timer.After(delay, PumpOutbox)
end

local function QueueComm(message, target, prio, kind)
    if not target or target == "" or #message > MAX_COMM_BYTES then return end
    table.insert(outbox, { message = message, target = target, prio = prio, kind = kind, attempts = 0 })
    if #outbox > OUTBOX_CAP then table.remove(outbox, 1) end
    SchedulePump(0)
end

-- Ersetzt einen noch nicht (vollstaendig) gesendeten Snapshot derselben Art durch den
-- neueren Stand, damit die Warteschlange bei haeufigen Aenderungen nicht anwaechst.
local function DropQueued(target, kind)
    for i = #outbox, 1, -1 do
        if outbox[i].target == target and outbox[i].kind == kind then
            table.remove(outbox, i)
        end
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

local function IsValidItem(id, finder, itemLink, quality, count, ts)
    return type(id) == "string" and #id <= 100 and id:match("^[^%c]+#%d+$")
        and type(finder) == "string" and finder ~= "" and #finder <= 100 and not finder:find("%c")
        and type(itemLink) == "string" and itemLink ~= "" and #itemLink <= MAX_ITEM_LINK_BYTES
        and not itemLink:find("%c")
        and type(quality) == "number" and quality >= 0 and quality <= 7
        and type(count) == "number" and count >= 1 and count <= 100000
        and type(ts) == "number" and ts >= 1 and ts <= time() + 300
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
    local normalizedSnapshots = {}
    for key, snap in pairs(GroupFoundCharDB.snapshots) do
        normalizedSnapshots[NormalizeKey(key)] = snap
    end
    GroupFoundCharDB.snapshots = normalizedSnapshots
    local normalizedInvites = {}
    for key, expiresAt in pairs(GroupFoundCharDB.pendingInvites) do
        if type(expiresAt) == "number" and expiresAt >= time() then
            normalizedInvites[NormalizeKey(key)] = expiresAt
        end
    end
    GroupFoundCharDB.pendingInvites = normalizedInvites
    for id, entry in pairs(GroupFoundCharDB.history) do
        if type(entry) ~= "table" or not IsValidItem(id, entry.finder, entry.itemLink,
                entry.quality, entry.count, entry.ts) then
            GroupFoundCharDB.history[id] = nil
        end
    end
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
    if not IsValidItem(id, finder, itemLink, quality, count, ts) then return end
    if GroupFoundCharDB.history[id] then return end
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
    if type(itemLink) ~= "string" or #itemLink > MAX_ITEM_LINK_BYTES then return end

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
        QueueComm(message, target, 1, "ITEM")
    end
end

------------------------------------------------------------
-- Einladen (fügt bei Annahme beide Seiten gegenseitig zur Whitelist hinzu)
------------------------------------------------------------

function GroupFound.SendInvite(rawName)
    local raw = trim(rawName)
    if raw == "" then return end
    local key = NormalizeKey(raw)

    if IsSameCharacter(raw, GetSelfFullName()) then
        GroupFound.Print(L.MSG_CANNOT_INVITE_SELF)
        return
    end
    if GroupFoundDB.whitelist[key] then
        GroupFound.Print(L.MSG_ALREADY_LINKED:format(raw))
        return
    end

    if SendComm("INV", raw) then
        GroupFoundCharDB.pendingInvites[key] = time() + PENDING_INVITE_TTL
        GroupFound.Print(L.MSG_INVITE_SENT:format(raw))
    else
        GroupFound.Print(L.MSG_INVITE_FAILED:format(raw))
    end
end

StaticPopupDialogs["GROUPFOUND_INVITE"] = {
    text = "%s",
    button1 = L.POPUP_ACCEPT,
    button2 = L.POPUP_DECLINE,
    OnAccept = function(self, data)
        if not data or not data.sender then return end
        if not SendComm("ACC", data.sender) then
            GroupFound.Print(L.MSG_INVITE_FAILED:format(data.sender))
            return
        end
        GroupFound.AddName(data.sender)
        GroupFound.GossipPush()
        if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
    end,
    OnCancel = function(self, data)
        if data and data.sender then SendComm("DEC", data.sender) end
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

function GroupFound.ShowInvitePopup(sender)
    if not sender or sender == "" or IsSameCharacter(sender, GetSelfFullName()) then return end
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
            return info.itemID, info.stackCount or 1, info.hyperlink
        end
        return nil
    end
    local itemLink = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not itemLink then return nil end
    local _, count = GetContainerItemInfo(bag, slot)
    local itemID = GetItemInfoInstant(itemLink)
    if not itemID then return nil end
    return itemID, count or 1, itemLink
end

-- Reduziert einen Item-Link auf "item:ID:enchant:gem1..4:suffix:unique" (ohne Farbcode/
-- Name/Spielerlevel), damit ein Bag-Snapshot in wenige Chunks passt. Liefert nil, wenn
-- der Link keine Zusatzdaten (Zufallsverzauberung, Verzauberung, Edelsteine) enthaelt -
-- dann reicht die itemID.
local function CompactItemString(link)
    local str = type(link) == "string" and link:match("item:[%-%d:]+")
    if not str then return nil end
    local fields = {}
    for field in (str .. ":"):gmatch("([^:]*):") do
        table.insert(fields, field)
    end
    local parts = { "item", fields[2] or "" }
    local hasExtra = false
    for i = 3, 9 do
        local f = fields[i] or ""
        if f ~= "" and f ~= "0" then hasExtra = true end
        table.insert(parts, f)
    end
    if not hasExtra then return nil end
    return table.concat(parts, ":")
end

local function EnsureSnapshot(key)
    GroupFoundCharDB.snapshots[key] = GroupFoundCharDB.snapshots[key] or {}
    return GroupFoundCharDB.snapshots[key]
end

function GroupFound.CaptureBags()
    if not GroupFoundCharDB then return end
    local counts = {}
    local links = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = GetBagNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID, count, link = GetBagSlotItem(bag, slot)
            if itemID then
                counts[itemID] = (counts[itemID] or 0) + count
                local compact = CompactItemString(link)
                if compact then links[itemID] = compact end
            end
        end
    end
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.bags = counts
    snap.bagLinks = links
    snap.bagsUpdatedAt = time()
    GroupFound.PushSnapshotKind("BAGS")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

function GroupFound.CaptureBank()
    if not GroupFoundCharDB then return end
    local counts = {}
    local links = {}
    local bankBags = { -1 }
    for i = 1, (NUM_BANKBAGSLOTS or 7) do
        table.insert(bankBags, 4 + i) -- Bank-Taschen liegen ab Bag-ID 5
    end
    for _, bag in ipairs(bankBags) do
        local slots = GetBagNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID, count, link = GetBagSlotItem(bag, slot)
            if itemID then
                counts[itemID] = (counts[itemID] or 0) + count
                local compact = CompactItemString(link)
                if compact then links[itemID] = compact end
            end
        end
    end
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.bank = counts
    snap.bankLinks = links
    snap.bankUpdatedAt = time()
    GroupFound.PushSnapshotKind("BANK")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

-- Berufe: Retail/BCC/MoP-Classic liefern sie ueber GetProfessions (plus Rezepte als
-- Spellbook-Tabs). Classic Era hat weder GetProfessions noch Berufs-Tabs im Zauberbuch:
-- dort stehen die Berufe im Faehigkeiten-Fenster (GetSkillLineInfo) und die Rezepte sind
-- nur bei geoeffnetem Berufe-Fenster lesbar (GetTradeSkill*/GetCraft*).
local KNOWN_PROFESSION_SPELLS = { 2259, 2018, 7411, 4036, 2108, 2575, 2366, 8613, 3908, 2550, 3273, 7620 }
local ENGLISH_PROFESSION_NAMES = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking",
    "Mining", "Skinning", "Tailoring", "Cooking", "First Aid", "Fishing",
}

-- GetSpellInfo wurde in neueren Clients nach C_Spell.GetSpellInfo verschoben.
function GroupFound.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" then return info.name end
        if type(info) == "string" then return info end
    end
    if GetSpellInfo then return (GetSpellInfo(spellID)) end
    return nil
end

local function ReadSkillLines()
    local lines = {}
    if not (GetNumSkillLines and GetSkillLineInfo) then return lines end

    -- Eingeklappte Kopfzeilen verbergen ihre Eintraege; kurz aufklappen und danach wieder
    -- einklappen (von unten nach oben, damit die Indizes stabil bleiben).
    local collapsed = {}
    if ExpandSkillHeader and CollapseSkillHeader then
        for i = GetNumSkillLines(), 1, -1 do
            local name, isHeader, isExpanded = GetSkillLineInfo(i)
            if isHeader and not isExpanded then
                collapsed[name] = true
                ExpandSkillHeader(i)
            end
        end
    end

    local total = GetNumSkillLines()
    for i = 1, total do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        table.insert(lines, { name = name, header = isHeader and true or false, rank = rank or 0, maxRank = maxRank or 0 })
    end

    if next(collapsed) then
        for i = total, 1, -1 do
            local name, isHeader = GetSkillLineInfo(i)
            if isHeader and collapsed[name] then CollapseSkillHeader(i) end
        end
    end
    return lines
end

-- Erkennt den Berufe-Block ohne feste Uebersetzungstabelle: entweder traegt die Kopfzeile
-- den lokalisierten Namen (TRADE_SKILLS/SECONDARY_SKILLS) oder der Block enthaelt einen
-- bekannten Berufs-Zauber (Name kommt aus GetSpellInfo, ist also lokalisiert).
local function CollectSkillLineProfessions(lines)
    local knownNames = {}
    for _, spellID in ipairs(KNOWN_PROFESSION_SPELLS) do
        local spellName = GroupFound.GetSpellName(spellID)
        if spellName then knownNames[spellName] = true end
    end
    for _, name in ipairs(ENGLISH_PROFESSION_NAMES) do knownNames[name] = true end

    local blocks = {}
    local current
    for _, line in ipairs(lines) do
        if line.header then
            current = { header = line.name, entries = {} }
            table.insert(blocks, current)
        elseif current and line.name then
            table.insert(current.entries, line)
        end
    end

    local professions = {}
    for _, block in ipairs(blocks) do
        local isProfessionBlock = block.header == TRADE_SKILLS or block.header == SECONDARY_SKILLS
        if not isProfessionBlock then
            for _, entry in ipairs(block.entries) do
                if knownNames[entry.name] then isProfessionBlock = true break end
            end
        end
        if isProfessionBlock then
            for _, entry in ipairs(block.entries) do
                if entry.maxRank > 1 then
                    table.insert(professions, { name = entry.name, level = entry.rank, maxLevel = entry.maxRank })
                end
            end
        end
    end

    -- Letzter Ausweg (Kopfzeilen nicht erkennbar): jede Fertigkeit mit bekanntem Berufsnamen.
    if #professions == 0 then
        for _, block in ipairs(blocks) do
            for _, entry in ipairs(block.entries) do
                if entry.maxRank > 1 and knownNames[entry.name] then
                    table.insert(professions, { name = entry.name, level = entry.rank, maxLevel = entry.maxRank })
                end
            end
        end
    end
    return professions
end

local lastProfSignature = ""
local lastRecipeSignature = ""

local function ProfessionsSignature(professions)
    local parts = {}
    for _, p in ipairs(professions) do
        table.insert(parts, p.name .. ":" .. p.level .. ":" .. p.maxLevel)
    end
    return table.concat(parts, ";")
end

local function RecipesSignature(recipes)
    local names = {}
    for name in pairs(recipes) do table.insert(names, name) end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do
        table.insert(parts, name .. "=" .. #recipes[name])
    end
    return table.concat(parts, ";")
end

local function CaptureProfessionsImpl()
    local professions = {}
    local recipes = {}
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))

    -- pairs() statt ipairs(): GetProfessions() kann Luecken in der Mitte liefern
    -- (z.B. keine Erstberufe, aber Kochen) - ipairs wuerde beim ersten nil abbrechen.
    local profNames = {}
    if GetProfessions and GetProfessionInfo then
        local profIndices = { GetProfessions() }
        for _, index in pairs(profIndices) do
            if index then
                local name, _, skillLevel, maxSkillLevel = GetProfessionInfo(index)
                if name then
                    table.insert(professions, { name = name, level = skillLevel or 0, maxLevel = maxSkillLevel or 0 })
                end
            end
        end
    end
    if #professions == 0 then
        professions = CollectSkillLineProfessions(ReadSkillLines())
    end
    for _, p in ipairs(professions) do profNames[p.name] = true end

    -- Bereits gelesene Rezepte (aus dem Berufe-Fenster) bleiben erhalten, solange der
    -- Beruf noch gelernt ist.
    for name, ids in pairs(snap.recipes or {}) do
        if profNames[name] then recipes[name] = ids end
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

    local profSignature = ProfessionsSignature(professions)
    local recipeSignature = RecipesSignature(recipes)
    local profChanged = profSignature ~= lastProfSignature
    local recipesChanged = recipeSignature ~= lastRecipeSignature
    lastProfSignature = profSignature
    lastRecipeSignature = recipeSignature

    snap.professions = professions
    snap.recipes = recipes
    if profChanged or not snap.profUpdatedAt then
        snap.profUpdatedAt = time()
        GroupFound.PushSnapshotKind("PROF")
    end
    if recipesChanged or not snap.recipesUpdatedAt then
        snap.recipesUpdatedAt = time()
        GroupFound.PushSnapshotKind("RECIPES")
    end
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

-- Das kurze Auf-/Einklappen der Faehigkeiten-Kopfzeilen loest selbst SKILL_LINES_CHANGED
-- aus; dieses Zeitfenster verhindert eine Endlosschleife aus Erfassung und Event.
local skillEventsIgnoredUntil = 0

function GroupFound.CaptureProfessions()
    if not GroupFoundCharDB then return end
    skillEventsIgnoredUntil = (GetTime and GetTime() or 0) + 0.5
    local ok, err = pcall(CaptureProfessionsImpl)
    if not ok then
        GroupFound.Print("CaptureProfessions error: " .. tostring(err))
    end
end

-- Liest die Rezepte des gerade geoeffneten Berufe-Fensters (Classic Era). Handwerksberufe
-- nutzen die TradeSkill-API, Verzauberkunst das Craft-Fenster. Eingeklappte Kategorien
-- verbergen ihre Rezepte und werden deshalb kurz aufgeklappt und wieder eingeklappt.
local recipeEventsIgnoredUntil = 0

local function ReadRecipeList(api)
    local collapsed = {}
    if api.expand and api.collapse then
        for i = api.num(), 1, -1 do
            local name, kind, expanded = api.info(i)
            if kind == "header" and not expanded then
                collapsed[name] = true
                api.expand(i)
            end
        end
    end

    local ids = {}
    local total = api.num()
    for i = 1, total do
        local _, kind = api.info(i)
        if kind ~= "header" then
            local id = (api.link(i) or ""):match("enchant:(%d+)")
            if id then table.insert(ids, tonumber(id)) end
        end
    end

    if next(collapsed) then
        for i = total, 1, -1 do
            local name, kind = api.info(i)
            if kind == "header" and collapsed[name] then api.collapse(i) end
        end
    end
    return ids
end

local function ReadOpenRecipes()
    local profName, ids
    if GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillRecipeLink then
        local name = GetTradeSkillLine()
        if name and name ~= "UNKNOWN" and GetNumTradeSkills() > 0 then
            profName = name
            ids = ReadRecipeList({
                num = GetNumTradeSkills,
                info = function(i) local n, t, _, e = GetTradeSkillInfo(i) return n, t, e end,
                link = GetTradeSkillRecipeLink,
                expand = ExpandTradeSkillSubClass,
                collapse = CollapseTradeSkillSubClass,
            })
        end
    end
    if (not ids or #ids == 0) and GetCraftDisplaySkillLine and GetNumCrafts and GetCraftRecipeLink then
        local name = GetCraftDisplaySkillLine()
        if name and name ~= "" and GetNumCrafts() > 0 then
            profName = name
            ids = ReadRecipeList({
                num = GetNumCrafts,
                info = function(i) local n, _, t, _, e = GetCraftInfo(i) return n, t, e end,
                link = GetCraftRecipeLink,
                expand = ExpandCraftSkillLine,
                collapse = CollapseCraftSkillLine,
            })
        end
    end

    -- Das Schmelz-Fenster gehoert zum Beruf Bergbau.
    if profName and profName == GroupFound.GetSpellName(2656) then
        profName = GroupFound.GetSpellName(2575) or profName
    end
    return profName, ids or {}
end

function GroupFound.CaptureOpenRecipes()
    if not GroupFoundCharDB then return end
    recipeEventsIgnoredUntil = (GetTime and GetTime() or 0) + 1.5
    local ok, profName, ids = pcall(ReadOpenRecipes)
    if not ok then
        GroupFound.Print("CaptureOpenRecipes error: " .. tostring(profName))
        return
    end
    if not profName or #ids == 0 then return end
    local snap = EnsureSnapshot(NormalizeKey(GetSelfFullName()))
    snap.recipes = snap.recipes or {}
    snap.recipes[profName] = ids
    local signature = RecipesSignature(snap.recipes)
    if signature == lastRecipeSignature then return end
    lastRecipeSignature = signature
    snap.recipesUpdatedAt = time()
    GroupFound.PushSnapshotKind("RECIPES")
    if GroupFound.RefreshGroupUI then GroupFound.RefreshGroupUI() end
end

-- /gf debug: gibt aus, was die Berufs-Erkennung sieht und was von anderen Mitgliedern
-- angekommen ist (zur Fehlersuche, da sich Classic-Clients bei Berufen unterscheiden).
function GroupFound.DebugSync()
    local function out(text) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffGF debug:|r " .. text) end
    out("GroupFound " .. GetAddonVersion())
    out(("API: GetProfessions=%s GetNumSkillLines=%s GetSpellInfo=%s C_Spell=%s TradeSkill=%s Craft=%s"):format(
        tostring(GetProfessions ~= nil), tostring(GetNumSkillLines ~= nil), tostring(GetSpellInfo ~= nil),
        tostring(C_Spell ~= nil and C_Spell.GetSpellInfo ~= nil), tostring(GetNumTradeSkills ~= nil),
        tostring(GetNumCrafts ~= nil)))

    local okLines, lines = pcall(ReadSkillLines)
    if not okLines then out("ReadSkillLines error: " .. tostring(lines)) lines = {} end
    out("skill lines: " .. #lines)
    for i, line in ipairs(lines) do
        if i > 45 then out("  ...") break end
        out(("  %s%s %s/%s"):format(line.header and "[H] " or "", tostring(line.name), line.rank, line.maxRank))
    end
    local okProf, detected = pcall(CollectSkillLineProfessions, lines)
    if okProf then
        local names = {}
        for _, p in ipairs(detected) do table.insert(names, p.name .. " " .. p.level .. "/" .. p.maxLevel) end
        out("detected professions: " .. (#names > 0 and table.concat(names, ", ") or "none"))
    else
        out("CollectSkillLineProfessions error: " .. tostring(detected))
    end

    local okTs, tsErr = pcall(function()
        out(("tradeskill window: line=%s rows=%s | craft window: line=%s rows=%s"):format(
            tostring(GetTradeSkillLine and (GetTradeSkillLine())), tostring(GetNumTradeSkills and GetNumTradeSkills()),
            tostring(GetCraftDisplaySkillLine and (GetCraftDisplaySkillLine())), tostring(GetNumCrafts and GetNumCrafts())))
        local tabs = {}
        for i = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
            local tabName, _, offset, numSpells = GetSpellTabInfo(i)
            table.insert(tabs, ("%s(%s)"):format(tostring(tabName), tostring(numSpells)))
        end
        out("spell tabs: " .. table.concat(tabs, ", "))
    end)
    if not okTs then out("window/tab debug error: " .. tostring(tsErr)) end

    if not GroupFoundCharDB then return end
    local selfSnap = GroupFoundCharDB.snapshots[NormalizeKey(GetSelfFullName())]
    out(("own snapshot: professions=%d recipes=%s gold=%s"):format(
        selfSnap and selfSnap.professions and #selfSnap.professions or 0,
        selfSnap and selfSnap.recipes and RecipesSignature(selfSnap.recipes) or "-",
        tostring(selfSnap and selfSnap.gold)))
    out("send queue: " .. #outbox)
    for _, entry in ipairs(GroupFound.GetSortedList()) do
        local snap = GroupFoundCharDB.snapshots[entry.key]
        local age = snap and snap.profUpdatedAt and (time() - snap.profUpdatedAt) or nil
        out(("member %s (v%s): professions=%d (age %s) recipes=%s gold=%s bags=%s"):format(
            entry.display,
            tostring(memberVersions[entry.key] or "unknown"),
            snap and snap.professions and #snap.professions or 0,
            age and (age .. "s") or "never",
            snap and snap.recipes and RecipesSignature(snap.recipes) or "-",
            tostring(snap and snap.gold), tostring(snap and snap.bagsUpdatedAt ~= nil)))
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

local function ThrottledCapture(kind, fn, delay)
    if captureThrottle[kind] then return end
    captureThrottle[kind] = true
    C_Timer.After(delay or 3, function()
        captureThrottle[kind] = nil
        fn()
    end)
end

------------------------------------------------------------
-- Snapshot-Payloads (Versand/Empfang, chunked)
------------------------------------------------------------

-- Der Item-Link wird mitgeschickt, damit das Tooltip beim Empfänger die konkrete
-- Ausprägung zeigen kann (z.B. den gewürfelten Bonus bei Items mit Zufallsverzauberung
-- wie "Grunt's Belt") statt nur der Basis-itemID, die WoW ohne Link nur als generisches
-- "<Random enchantment>" auflösen kann.
local function BuildCountsPayload(counts, links)
    local parts = {}
    for itemID, count in pairs(counts or {}) do
        local link = links and links[itemID]
        if link then
            table.insert(parts, itemID .. ":" .. count .. ":" .. link)
        else
            table.insert(parts, itemID .. ":" .. count)
        end
    end
    return table.concat(parts, ";")
end

local function ParseCountsPayload(payload)
    local counts = {}
    local links = {}
    for entry in (payload or ""):gmatch("[^;]+") do
        local itemID, count, link = entry:match("^(%d+):(%d+):(.+)$")
        if not itemID then
            itemID, count = entry:match("^(%d+):(%d+)$")
        end
        if itemID then
            counts[tonumber(itemID)] = tonumber(count)
            local itemString = link and link:match("item:[%-%d:]+")
            if itemString and #itemString <= 100 then links[tonumber(itemID)] = itemString end
        end
    end
    return counts, links
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
        for _, spellID in ipairs(spellIDs) do
            table.insert(parts, profName .. ":" .. spellID)
        end
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
            map[name] = map[name] or {}
            for _, id in ipairs(ids) do table.insert(map[name], id) end
        end
    end
    return map
end

local SNAP_SEND_PRIORITY = { GOLD = 1, PROF = 1, BAGS = 2, BANK = 2, RECIPES = 3 }

function GroupFound.SendSnapshotChunks(kind, payload, updatedAt, targets)
    if not targets or #targets == 0 or not updatedAt then return end

    local entries = {}
    for entry in (payload .. ";"):gmatch("(.-);") do
        if entry ~= "" then table.insert(entries, entry) end
    end

    local chunks = {}
    local current = {}
    local currentBytes = 0
    for _, entry in ipairs(entries) do
        if #entry > SNAP_PAYLOAD_BYTES then return end
        if currentBytes > 0 and currentBytes + 1 + #entry > SNAP_PAYLOAD_BYTES then
            table.insert(chunks, table.concat(current, ";"))
            current = {}
            currentBytes = 0
        end
        table.insert(current, entry)
        currentBytes = currentBytes + #entry + (currentBytes > 0 and 1 or 0)
    end
    if #current > 0 or #chunks == 0 then
        table.insert(chunks, table.concat(current, ";"))
    end
    if #chunks > MAX_SNAP_CHUNKS then return end

    local prio = SNAP_SEND_PRIORITY[kind] or 3
    for _, target in ipairs(targets) do
        DropQueued(target, "SNAP" .. kind)
        for idx, chunkPayload in ipairs(chunks) do
            local msg = table.concat({ "SNAP", kind, tostring(updatedAt), tostring(idx), tostring(#chunks), chunkPayload }, SEP)
            QueueComm(msg, target, prio, "SNAP" .. kind)
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
        GroupFound.SendSnapshotChunks("BAGS", BuildCountsPayload(snap.bags, snap.bagLinks), snap.bagsUpdatedAt, targets)
    elseif kind == "BANK" and snap.bankUpdatedAt then
        GroupFound.SendSnapshotChunks("BANK", BuildCountsPayload(snap.bank, snap.bankLinks), snap.bankUpdatedAt, targets)
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
        GroupFound.SendSnapshotChunks("BAGS", BuildCountsPayload(snap.bags, snap.bagLinks), snap.bagsUpdatedAt, targets)
    end
    if snap.bankUpdatedAt then
        GroupFound.SendSnapshotChunks("BANK", BuildCountsPayload(snap.bank, snap.bankLinks), snap.bankUpdatedAt, targets)
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
    if kind ~= "BAGS" and kind ~= "BANK" and kind ~= "PROF" and kind ~= "RECIPES" and kind ~= "GOLD" then return end
    if totalChunks < 1 or totalChunks > MAX_SNAP_CHUNKS or chunkIdx < 1 or chunkIdx > totalChunks then return end
    if updatedAt < 1 or updatedAt > time() + 300 or #payload > SNAP_PAYLOAD_BYTES then return end

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
        snap.bags, snap.bagLinks = ParseCountsPayload(fullPayload)
        snap.bagsUpdatedAt = updatedAt
    elseif kind == "BANK" and updatedAt > (snap.bankUpdatedAt or 0) then
        snap.bank, snap.bankLinks = ParseCountsPayload(fullPayload)
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
    GroupFound.gossipOffset = GroupFound.gossipOffset or 0
    if GroupFound.gossipOffset >= #historyList then GroupFound.gossipOffset = 0 end
    local first = GroupFound.gossipOffset + 1
    local last = math.min(first + GOSSIP_ITEM_BATCH - 1, #historyList)
    for i = first, last do
        local e = historyList[i]
        local itemMsg = table.concat(
            { "ITEM", e.id, e.finder, e.itemLink, tostring(e.quality), tostring(e.count), tostring(e.ts) },
            SEP
        )
        for _, target in ipairs(targets) do
            QueueComm(itemMsg, target, 4, "ITEM")
        end
    end
    GroupFound.gossipOffset = last >= #historyList and 0 or last

    for _, target in ipairs(targets) do
        DropQueued(target, "HI")
        QueueComm("HI" .. SEP .. GetAddonVersion(), target, 1, "HI")
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
            if type(GroupFoundCharDB.pendingInvites[key]) ~= "number" or GroupFoundCharDB.pendingInvites[key] < time() then
                GroupFoundCharDB.pendingInvites[key] = nil
                return
            end
            GroupFoundCharDB.pendingInvites[key] = nil
            local confirmedName = sender
            if not sender:find("-", 1, true) and key:find("-", 1, true) then
                confirmedName = sender .. "-" .. GetRealmName()
            end
            GroupFound.AddName(confirmedName)
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
    elseif typ == "HI" then
        local key = FindWhitelistKey(sender)
        local version = rest:match("^%d+%.%d+[%d%.]*$")
        if key and version and #version <= 20 then
            TouchLastSeen(sender)
            memberVersions[key] = version
            NotifyIfNewer(version)
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
-- Nicht in jedem Client vorhanden (Craft-Fenster nur Classic Era): unbekannte Events
-- duerfen das Laden nicht abbrechen.
for _, recipeEvent in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE" }) do
    pcall(commEventFrame.RegisterEvent, commEventFrame, recipeEvent)
end

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
        -- Faehigkeiten-Daten sind kurz nach dem Login teils noch leer; erneut lesen
        -- (sendet nur, wenn sich etwas geaendert hat).
        C_Timer.After(15, GroupFound.CaptureProfessions)
        C_Timer.After(60, GroupFound.CaptureProfessions)
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
        if (GetTime and GetTime() or 0) < skillEventsIgnoredUntil then return end
        ThrottledCapture("professions", GroupFound.CaptureProfessions)
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE"
            or event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
        if (GetTime and GetTime() or 0) < recipeEventsIgnoredUntil then return end
        ThrottledCapture("recipes", GroupFound.CaptureOpenRecipes, 0.5)
    end
end)
