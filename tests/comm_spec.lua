-- Run with a Lua 5.1-compatible interpreter from the repository root:
-- lua tests/comm_spec.lua

local now = 1000
local sent = {}
local frames = {}
local popup
local sendResult = 0
local budget = math.huge
local timers = {}

function time() return now end
function GetLocale() return "enUS" end
function GetRealmName() return "My Realm" end
function UnitName(unit)
    if unit == "player" then return "Alice" end
end
function strsplit(delimiter, value, limit)
    local parts = {}
    value = value or ""
    local start = 1
    while not limit or #parts < limit - 1 do
        local pos = string.find(value, delimiter, start, true)
        if not pos then break end
        table.insert(parts, string.sub(value, start, pos - 1))
        start = pos + #delimiter
    end
    table.insert(parts, string.sub(value, start))
    return (table.unpack or unpack)(parts)
end
function CreateFrame()
    local frame = {}
    function frame:RegisterEvent() end
    function frame:SetScript(_, fn) self.onEvent = fn end
    table.insert(frames, frame)
    return frame
end
function StaticPopup_Show(_, _, _, data) popup = data end
StaticPopupDialogs = {}
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local tickers = {}
C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
    NewTicker = function(_, fn) table.insert(tickers, fn) end,
}

-- Runs queued timers (the paced send queue) until idle; each tick refills one send token.
local function flush()
    local guard = 0
    while #timers > 0 do
        guard = guard + 1
        assert(guard < 20000, "timer loop did not settle")
        budget = budget + 1
        table.remove(timers, 1)()
    end
end
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return 0 end,
    SendAddonMessage = function(_, message, _, target)
        if sendResult == 0 and budget < 1 then return 3 end
        if sendResult == 0 then budget = budget - 1 end
        table.insert(sent, { message = message, target = target })
        return sendResult
    end,
}

dofile("GroupFound/Locales.lua")
dofile("GroupFound/Core.lua")
dofile("GroupFound/Comm.lua")
GroupFound.InitDB()
GroupFound.InitCharDB()
GroupFoundDB.whitelist["legacy-my realm"] = "Legacy-My Realm"
GroupFoundCharDB.snapshots["legacy-my realm"] = { gold = 123 }
GroupFound.InitDB()
GroupFound.InitCharDB()
assert(GroupFoundDB.whitelist["legacy-myrealm"] == "Legacy-My Realm")
assert(GroupFound.GetMemberSnapshot("legacy-myrealm").gold == 123)

local function receive(message, sender)
    frames[2].onEvent(frames[2], "CHAT_MSG_ADDON", "GroupFound", message, "WHISPER", sender)
end

-- A local player's reply may omit the realm even when the invite included it.
GroupFound.SendInvite("Bob-My Realm")
assert(GroupFoundCharDB.pendingInvites["bob-myrealm"])
receive("ACC", "Bob")
assert(GroupFoundDB.whitelist["bob-myrealm"] == "Bob-My Realm")
assert(GroupFound.IsWhitelisted("Bob"))

-- A failed send must not leave an open invitation.
sendResult = 3
GroupFound.SendInvite("Carol")
assert(not GroupFoundCharDB.pendingInvites.carol)
sendResult = 0

-- An expired reply must not add a member, including after loading saved state.
GroupFound.SendInvite("Dave")
now = now + 61
receive("ACC", "Dave-MyRealm")
assert(not GroupFoundDB.whitelist.dave)
assert(not GroupFoundCharDB.pendingInvites.dave)

-- Accepting a received invitation sends a reply before adding the sender.
receive("INV", "Eve-MyRealm")
assert(popup and popup.sender == "Eve-MyRealm")
sendResult = 3
StaticPopupDialogs.GROUPFOUND_INVITE.OnAccept(nil, popup)
assert(not GroupFoundDB.whitelist["eve-myrealm"])
sendResult = 0
StaticPopupDialogs.GROUPFOUND_INVITE.OnAccept(nil, popup)
assert(GroupFoundDB.whitelist["eve-myrealm"])

-- Malformed item data must not poison future gossip batches.
local historyBefore = #GroupFound.GetSortedHistory()
receive(table.concat({ "ITEM", "bob#1", "Bob", "", "2", "1", "1000" }, "\1"), "Bob")
assert(#GroupFound.GetSortedHistory() == historyBefore)

-- Snapshot messages must fit the API limit and reassemble from chunks.
sent = {}
local entries = {}
for i = 1, 60 do table.insert(entries, (1000 + i) .. ":1") end
GroupFound.SendSnapshotChunks("BAGS", table.concat(entries, ";"), now, { "Bob" })
flush()
assert(#sent > 1)
for _, entry in ipairs(sent) do
    assert(#entry.message <= 255)
    receive(entry.message, "Bob")
end
assert(GroupFound.GetMemberSnapshot("bob-myrealm").bags[1060] == 1)

-- Successive gossip rounds must eventually include older history entries.
GroupFoundCharDB.history = {}
for i = 1, 30 do
    GroupFound.MergeItem("bob#" .. i, "Bob", "item:1", 2, 1, now - i)
end
sent = {}
GroupFound.gossipOffset = 0
GroupFound.GossipPush({ "Bob" })
GroupFound.GossipPush({ "Bob" })
flush()
local itemIDs = {}
for _, entry in ipairs(sent) do
    local id = entry.message:match("^ITEM\1([^\1]+)")
    if id then itemIDs[id] = true end
end
local count = 0
for _ in pairs(itemIDs) do count = count + 1 end
assert(count == 30)

-- Under client throttling, small gold/profession snapshots must not starve behind bulk data.
now = now + 10
budget = 3
sent = {}
local recipeEntries = {}
for i = 1, 150 do table.insert(recipeEntries, "Blacksmithing:" .. (10000 + i)) end
GroupFound.SendSnapshotChunks("RECIPES", table.concat(recipeEntries, ";"), now, { "Bob" })
GroupFound.SendSnapshotChunks("BAGS", table.concat(entries, ";"), now, { "Bob" })
GroupFound.SendSnapshotChunks("GOLD", "1234567", now, { "Bob" })
GroupFound.SendSnapshotChunks("PROF", "Blacksmithing:150:300;Mining:75:150", now, { "Bob" })
flush()
local firstKinds = {}
for i = 1, 2 do firstKinds[sent[i].message:match("^SNAP\1(%u+)")] = true end
assert(firstKinds.GOLD and firstKinds.PROF, "gold/prof must be sent before bulk chunks")
for _, entry in ipairs(sent) do
    assert(#entry.message <= 255)
    receive(entry.message, "Bob")
end
local bobSnap = GroupFound.GetMemberSnapshot("bob-myrealm")
assert(bobSnap.gold == 1234567)
assert(#bobSnap.professions == 2 and bobSnap.professions[1].name == "Blacksmithing")
assert(#bobSnap.recipes.Blacksmithing == 150)

-- A newer snapshot replaces a still-queued older one of the same kind.
sent = {}
budget = 0
GroupFound.SendSnapshotChunks("GOLD", "1", now + 1, { "Bob" })
GroupFound.SendSnapshotChunks("GOLD", "2", now + 2, { "Bob" })
flush()
assert(#sent == 1 and sent[1].message:find("\1" .. (now + 2) .. "\1", 1, true))

-- Bag links carry only random-enchant/enchant/gem data and are validated on receipt.
receive(table.concat({ "SNAP", "BANK", tostring(now + 3), "1", "1",
    "2589:5;19870:1:item:19870:0:0:0:0:0:1234:5678;3:1:garbage" }, "\1"), "Bob")
bobSnap = GroupFound.GetMemberSnapshot("bob-myrealm")
assert(bobSnap.bank[2589] == 5 and bobSnap.bankLinks[2589] == nil)
assert(bobSnap.bankLinks[19870] == "item:19870:0:0:0:0:0:1234:5678")
assert(bobSnap.bankLinks[3] == nil)

-- Classic Era: professions come from the skill window (even with collapsed headers) and
-- recipes from the open trade skill window.
local skillTree = {
    { name = "Class Skills", header = true, expanded = true, children = { { name = "Defense", rank = 1, max = 5 } } },
    { name = "Professions", header = true, expanded = false, children = {
        { name = "Mining", rank = 150, max = 225 }, { name = "Blacksmithing", rank = 100, max = 150 } } },
    { name = "Secondary Skills", header = true, expanded = true, children = { { name = "Cooking", rank = 50, max = 75 } } },
    { name = "Weapon Skills", header = true, expanded = true, children = { { name = "Swords", rank = 100, max = 300 } } },
}
local function visibleSkillLines()
    local list = {}
    for hi, h in ipairs(skillTree) do
        table.insert(list, { h = hi })
        if h.expanded then
            for ci = 1, #h.children do table.insert(list, { h = hi, c = ci }) end
        end
    end
    return list
end
function GetNumSkillLines() return #visibleSkillLines() end
function GetSkillLineInfo(i)
    local e = visibleSkillLines()[i]
    if not e then return end
    if not e.c then
        local h = skillTree[e.h]
        return h.name, 1, h.expanded and 1 or nil
    end
    local child = skillTree[e.h].children[e.c]
    return child.name, nil, nil, child.rank, 0, 0, child.max
end
function ExpandSkillHeader(i)
    local e = visibleSkillLines()[i]
    skillTree[e.h].expanded = true
end
function CollapseSkillHeader(i)
    local e = visibleSkillLines()[i]
    skillTree[e.h].expanded = false
end
local spellNames = { [2575] = "Mining", [2018] = "Blacksmithing", [2550] = "Cooking" }
function GetSpellInfo(id) return spellNames[id] end

sent = {}
GroupFound.CaptureProfessions()
local selfSnap = GroupFound.GetMemberSnapshot("alice-myrealm")
assert(#selfSnap.professions == 3, "expected Mining, Blacksmithing, Cooking")
assert(selfSnap.professions[1].name == "Mining" and selfSnap.professions[1].level == 150)
assert(selfSnap.professions[3].name == "Cooking")
assert(skillTree[2].expanded == false, "collapsed header must be restored")
flush()
local sawProf = false
for _, entry in ipairs(sent) do
    if entry.message:match("^SNAP\1PROF") then sawProf = true end
end
assert(sawProf, "profession snapshot must be sent")

function GetTradeSkillLine() return "Blacksmithing", 100, 150 end
function GetNumTradeSkills() return 3 end
function GetTradeSkillInfo(i) return "x", (i == 1) and "header" or "optimal" end
function GetTradeSkillRecipeLink(i) return "|cffffd000|Henchant:" .. (2660 + i) .. "|h[Recipe]|h|r" end
GroupFound.CaptureOpenRecipes()
selfSnap = GroupFound.GetMemberSnapshot("alice-myrealm")
assert(#selfSnap.recipes.Blacksmithing == 2 and selfSnap.recipes.Blacksmithing[1] == 2662)
GroupFound.CaptureProfessions()
assert(#GroupFound.GetMemberSnapshot("alice-myrealm").recipes.Blacksmithing == 2, "recipes survive recapture")

receive("HI\1" .. "2.0.5", "Bob")
assert(GroupFound.GetMemberVersion("bob-myrealm") == "2.0.5")
sent = {}
GroupFound.GossipPush({ "Bob" })
flush()
local sawHi = false
for _, entry in ipairs(sent) do
    if entry.message:match("^HI\1") then sawHi = true end
end
assert(sawHi, "gossip must announce the addon version")

-- Recipes under collapsed categories are read, and the categories are restored.
local tsTree = {
    { name = "Leather Armor", expanded = false, recipes = { 3001, 3002 } },
    { name = "Elemental", expanded = true, recipes = { 3003 } },
}
local function tsRows()
    local rows = {}
    for hi, h in ipairs(tsTree) do
        table.insert(rows, { h = hi })
        if h.expanded then
            for ri = 1, #h.recipes do table.insert(rows, { h = hi, r = ri }) end
        end
    end
    return rows
end
function GetTradeSkillLine() return "Leatherworking", 107, 150 end
function GetNumTradeSkills() return #tsRows() end
function GetTradeSkillInfo(i)
    local row = tsRows()[i]
    if not row.r then return tsTree[row.h].name, "header", 0, tsTree[row.h].expanded and 1 or nil end
    return "recipe", "optimal", 1, nil
end
function GetTradeSkillRecipeLink(i)
    local row = tsRows()[i]
    return "|cffffd000|Henchant:" .. tsTree[row.h].recipes[row.r] .. "|h[R]|h|r"
end
function ExpandTradeSkillSubClass(i) tsTree[tsRows()[i].h].expanded = true end
function CollapseTradeSkillSubClass(i) tsTree[tsRows()[i].h].expanded = false end
GroupFound.CaptureOpenRecipes()
local leather = GroupFound.GetMemberSnapshot("alice-myrealm").recipes.Leatherworking
assert(leather and #leather == 3, "recipes in collapsed categories must be included")
assert(tsTree[1].expanded == false and tsTree[2].expanded == true, "category state must be restored")

-- The client may not fire the profession window events; the periodic poll must still read
-- recipes, and must fall back to recipe names when links carry no spell ID.
frames[2].onEvent(frames[2], "PLAYER_LOGIN")
function GetTradeSkillLine() return "Blacksmithing", 100, 150 end
local function tsRecipeName(i) return "Recipe " .. tsRows()[i].r end
function GetTradeSkillInfo(i)
    local row = tsRows()[i]
    if not row.r then return tsTree[row.h].name, "header", 0, tsTree[row.h].expanded and 1 or nil end
    return tsRecipeName(i), "optimal", 1, nil
end
function GetTradeSkillRecipeLink(i)
    local row = tsRows()[i]
    if row.r == 1 then return "|Hunknown:xyz|h[x]|h|r" end
    return "|cffffd000|Hspell:" .. (4000 + row.r) .. "|h[x]|h|r"
end
local pollSnap = GroupFound.GetMemberSnapshot("alice-myrealm")
pollSnap.recipes.Blacksmithing = nil
now = now + 5
for _, tick in ipairs(tickers) do tick() end
sent = {}
flush()
local polled = GroupFound.GetMemberSnapshot("alice-myrealm").recipes.Blacksmithing
assert(polled and #polled == 3, "poll must capture recipes without any profession event")
local strings, numbers = 0, 0
for _, recipe in ipairs(polled) do
    if type(recipe) == "string" then strings = strings + 1 else numbers = numbers + 1 end
end
assert(strings == 2 and numbers == 1, "two name fallbacks (rows without a spell link) plus one spell ID")
for _, entry in ipairs(sent) do receive(entry.message, "Bob") end
local bobRecipes = GroupFound.GetMemberSnapshot("bob-myrealm").recipes.Blacksmithing
assert(bobRecipes and #bobRecipes == 3, "recipes must reach the other member")
local bobNames = 0
for _, recipe in ipairs(bobRecipes) do
    if type(recipe) == "string" then bobNames = bobNames + 1 end
end
assert(bobNames == 2, "name entries must survive the payload round trip")

-- A newer version announced by a member is reported once in chat.
assert(GroupFound.IsNewerVersion("2.0.10", "2.0.9") and GroupFound.IsNewerVersion("2.1", "2.0.9"))
assert(not GroupFound.IsNewerVersion("2.0.5", "2.0.5") and not GroupFound.IsNewerVersion("2.0.4", "2.0.5"))
function GetAddOnMetadata() return "2.0.5" end
local chatLines = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(chatLines, text) end }
receive("HI\1" .. "2.0.5", "Bob")
receive("HI\1" .. "2.0.6", "Bob")
receive("HI\1" .. "2.0.6", "Bob")
receive("HI\1" .. "evil |cffff0000text", "Bob")
local versionNotices = 0
for _, line in ipairs(chatLines) do
    if line:find("2.0.6", 1, true) then versionNotices = versionNotices + 1 end
end
assert(versionNotices == 1, "expected exactly one update notice, got " .. versionNotices)

GroupFound.DebugSync()

print("comm_spec: passed")
