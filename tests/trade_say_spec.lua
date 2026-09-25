-- Run with a Lua 5.1-compatible interpreter from the repository root:
-- lua tests/trade_say_spec.lua
--
-- SAY/YELL need a hardware event in the open world (patch 8.2.5+, also Classic Era), but
-- TRADE_SHOW usually comes from the server. The announcement therefore must never be
-- sent straight from the trade event outdoors; it waits for the next key press / world
-- click. In instances it is sent immediately.

local clock = 1000
local locale = "enUS"
local said = {}
local chat = {}
local cancelled = 0
local inInstance = false
local npcName, npcRealm = "Mallory", nil
local timers = {}
local frames = {}
local worldHooks = {}

function GetTime() return clock end
function GetLocale() return locale end
function GetRealmName() return "My Realm" end
function IsInInstance() return inInstance, inInstance and "party" or "none" end
function UnitName(unit)
    if unit == "npc" then return npcName, npcRealm end
    if unit == "player" then return "Alice" end
end
function CancelTrade() cancelled = cancelled + 1 end
function SendChatMessage(text, channel, _, target)
    table.insert(said, { text = text, channel = channel, target = target })
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
    local frame = { events = {}, scripts = {}, keyboard = false, propagate = false }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:EnableKeyboard(enabled) self.keyboard = enabled end
    function frame:SetPropagateKeyboardInput(enabled) self.propagate = enabled end
    table.insert(frames, frame)
    return frame
end
WorldFrame = { HookScript = function(_, name, fn) worldHooks[name] = fn end }
C_Timer = { After = function(_, fn) table.insert(timers, fn) end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(chat, text) end }
SlashCmdList = {}

local function loadAddon()
    GroupFound = nil
    frames, worldHooks, timers = {}, {}, {}
    dofile("GroupFound/Locales.lua")
    dofile("GroupFound/Core.lua")
    GroupFound.InitDB()
end

local function eventFrame() return frames[1] end
local function fire(event) eventFrame().scripts.OnEvent(eventFrame(), event) end
local function runTimers()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
end
local function sayFrame() return frames[2] end
local function reset()
    said, chat, cancelled = {}, {}, 0
    inInstance, npcName, npcRealm = false, "Mallory", nil
end
local function chatContains(needle)
    for _, line in ipairs(chat) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

loadAddon()

-- 1. Outdoors, not whitelisted: block, tell the player locally, do NOT call SAY yet.
reset()
fire("TRADE_SHOW")
assert(cancelled == 1, "trade must be cancelled")
assert(chatContains("Mallory"), "player must see the local block message")
assert(#said == 0, "SAY outdoors needs a hardware event and must not be sent from TRADE_SHOW")
assert(sayFrame() and sayFrame().keyboard, "keyboard listener must be armed while a say is pending")
assert(sayFrame().propagate, "keys must still reach the game")

-- 2. The next key press is a hardware event: the announcement goes out exactly once.
sayFrame().scripts.OnKeyDown(sayFrame(), "W")
assert(#said == 1, "expected one SAY after the key press, got " .. #said)
assert(said[1].channel == "SAY")
assert(said[1].text:find("GroupFound", 1, true) and said[1].text:find("Mallory", 1, true))
assert(not said[1].text:find("%s+,"), "no dangling space before a comma")
assert(sayFrame().keyboard == false, "keyboard listener must be released after sending")
sayFrame().scripts.OnKeyDown(sayFrame(), "W")
assert(#said == 1, "must not say twice")

-- 3. A click into the game world flushes it as well.
reset()
clock = clock + 30
npcName = "Trent"
fire("TRADE_SHOW")
assert(#said == 0)
worldHooks.OnMouseDown()
assert(#said == 1 and said[1].text:find("Trent", 1, true))
worldHooks.OnMouseDown()
assert(#said == 1)

-- 4. In an instance SAY is allowed without a hardware event.
reset()
clock = clock + 30
inInstance = true
npcName = "Peggy"
fire("TRADE_SHOW")
assert(#said == 1 and said[1].text:find("Peggy", 1, true), "instances announce immediately")
assert(cancelled == 1)

-- 5. Whitelisted players trade normally and nothing is announced.
reset()
clock = clock + 30
GroupFound.AddName("Victor")
npcName = "Victor"
fire("TRADE_SHOW")
assert(cancelled == 0 and #said == 0)
GroupFound.AddName("Wendy-My Realm")
npcName, npcRealm = "Wendy", "My Realm"
fire("TRADE_SHOW")
assert(cancelled == 0 and #said == 0, "whitelisted player with realm suffix")

-- 6. Cooldown per player against chat spam; other players are not affected.
reset()
clock = clock + 30
inInstance = true
npcName = "Mallory"
fire("TRADE_SHOW")
clock = clock + 5
fire("TRADE_SHOW")
assert(#said == 1, "second request within the cooldown must stay silent")
assert(cancelled == 2, "but every request is still cancelled")
npcName = "Trent"
fire("TRADE_SHOW")
assert(#said == 2, "another player is announced separately")
clock = clock + 11
npcName = "Mallory"
fire("TRADE_SHOW")
assert(#said == 3, "after the cooldown the same player is announced again")

-- 7. A stale pending announcement is dropped instead of surprising the player later.
reset()
clock = clock + 30
inInstance = false
npcName = "Oscar"
fire("TRADE_SHOW")
clock = clock + 61
sayFrame().scripts.OnKeyDown(sayFrame(), "W")
assert(#said == 0, "announcement older than a minute must not be sent")

-- 8. The npc name is sometimes not set yet at TRADE_SHOW; the retry still announces.
reset()
clock = clock + 30
npcName = nil
fire("TRADE_SHOW")
assert(#said == 0 and cancelled == 0, "nothing decided before the retry")
npcName = "Sybil"
runTimers()
assert(cancelled == 1)
sayFrame().scripts.OnKeyDown(sayFrame(), "W")
assert(#said == 1 and said[1].text:find("Sybil", 1, true))

-- 9. A newer pending announcement replaces an older one; only the latest is sent.
reset()
clock = clock + 30
npcName = "Alpha"
fire("TRADE_SHOW")
npcName = "Bravo"
fire("TRADE_SHOW")
worldHooks.OnMouseDown()
assert(#said == 1 and said[1].text:find("Bravo", 1, true))

-- 10. Every supported client language has a proper announcement text.
local languages = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW" }
for _, lang in ipairs(languages) do
    locale = lang
    loadAddon()
    local text = GroupFound.L.SAY_TRADE_BLOCKED
    assert(type(text) == "string" and text:find("%%s"), lang .. ": say text needs a name placeholder")
    assert(text:find("GroupFound", 1, true), lang .. ": say text must mention GroupFound")
    assert(#text:format("Mallory") <= 255, lang .. ": say text must fit one chat message")
end

print("trade_say_spec: passed")
