-- Run with a Lua 5.1-compatible interpreter from the repository root:
-- lua tests/comm_spec.lua

local now = 1000
local sent = {}
local frames = {}
local popup
local sendResult = 0

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
C_Timer = { After = function() end, NewTicker = function() end }
C_ChatInfo = {
    RegisterAddonMessagePrefix = function() return 0 end,
    SendAddonMessage = function(_, message, _, target)
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
local itemIDs = {}
for _, entry in ipairs(sent) do
    local id = entry.message:match("^ITEM\1([^\1]+)")
    if id then itemIDs[id] = true end
end
local count = 0
for _ in pairs(itemIDs) do count = count + 1 end
assert(count == 30)

print("comm_spec: passed")
