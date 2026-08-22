-- GroupFound
-- Erlaubt Handel (Trade-Fenster, Post, Auktionshaus-Zugriff) nur mit Spielern,
-- die manuell auf eine persönliche Whitelist gesetzt wurden.
-- Gedacht für WoW Classic Hardcore Regelwerke ("nur mit selbst gefundenen Spielern handeln").
--
-- Texte kommen aus Locales.lua (GroupFound.L), passend zur aktuellen Client-Sprache (GetLocale()).

GroupFound = GroupFound or {}
local ADDON_NAME = "GroupFound"
local L = GroupFound.L

------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------

function GroupFound.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GroupFound:|r " .. tostring(msg))
end

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

------------------------------------------------------------
-- SavedVariables / DB
------------------------------------------------------------

-- Der Schutz (Handel/Post/Auktionshaus blockieren) ist immer aktiv und kann
-- nicht abgeschaltet werden - es gibt bewusst keine Ein/Aus-Einstellungen dafür.
function GroupFound.InitDB()
    GroupFoundDB = GroupFoundDB or {}
    GroupFoundDB.whitelist = GroupFoundDB.whitelist or {}
    GroupFoundDB.minimapPos = GroupFoundDB.minimapPos or 200
end

------------------------------------------------------------
-- Whitelist Verwaltung
-- Einträge werden als "Anzeige-Name" (Originalschreibweise) gespeichert,
-- der Key im Table ist die kleingeschriebene Form für den Vergleich.
------------------------------------------------------------

function GroupFound.AddName(raw)
    raw = trim(raw)
    if raw == "" then return false end
    local key = raw:lower()
    GroupFoundDB.whitelist[key] = raw
    return true
end

function GroupFound.RemoveByKey(key)
    if not key then return end
    GroupFoundDB.whitelist[key] = nil
end

function GroupFound.RemoveName(raw)
    raw = trim(raw)
    if raw == "" then return end
    GroupFoundDB.whitelist[raw:lower()] = nil
end

-- Fügt das aktuell anvisierte Ziel zur Whitelist hinzu, sofern es ein anderer Spieler ist.
function GroupFound.AddCurrentTarget()
    if not UnitExists("target") then
        GroupFound.Print(L.MSG_NO_TARGET)
        return false
    end
    if not UnitIsPlayer("target") then
        GroupFound.Print(L.MSG_TARGET_NOT_PLAYER)
        return false
    end
    if UnitIsUnit("target", "player") then
        GroupFound.Print(L.MSG_TARGET_IS_SELF)
        return false
    end

    local name, realm = UnitName("target")
    if not name or name == "" then
        GroupFound.Print(L.MSG_TARGET_NAME_UNKNOWN)
        return false
    end

    local full = name
    if realm and realm ~= "" then
        full = name .. "-" .. realm
    end

    if GroupFound.AddName(full) then
        GroupFound.Print(L.MSG_ADDED:format(full))
        GroupFound.RefreshUI()
        return true
    end
    return false
end

-- Liefert eine nach Anzeigename sortierte Liste { {key=..., display=...}, ... }
function GroupFound.GetSortedList()
    local list = {}
    for key, display in pairs(GroupFoundDB.whitelist) do
        table.insert(list, { key = key, display = display })
    end
    table.sort(list, function(a, b) return a.display:lower() < b.display:lower() end)
    return list
end

-- Prüft ob (name, realm) auf der Whitelist steht.
-- realm darf nil/"" sein (Standardfall: gleicher Realm wie der Spieler).
function GroupFound.IsWhitelisted(name, realm)
    if not name or name == "" then return false end
    local lname = name:lower()
    if GroupFoundDB.whitelist[lname] then
        return true
    end
    if realm and realm ~= "" then
        local combined = (name .. "-" .. realm):lower()
        if GroupFoundDB.whitelist[combined] then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- Handel (Trade-Fenster)
------------------------------------------------------------

-- Hinweis: Eine automatische /say-Ankündigung an den blockierten Spieler wurde
-- bewusst nicht umgesetzt. Blizzard blockiert SendChatMessage-Aufrufe, die auf
-- CancelTrade() folgen, als "protected function" (ADDON_ACTION_BLOCKED) -
-- vermutlich ein Schutz gegen Scam-/Spam-Bots mit genau diesem Muster (Handel
-- abbrechen -> automatisch chatten). Das lässt sich nicht zuverlässig umgehen,
-- ohne eine echte Nutzeraktion (Klick/Tastendruck) vorauszusetzen.

local function EvaluateTrade(name, realm)
    if GroupFound.IsWhitelisted(name, realm) then
        return
    end

    GroupFound.Print(L.MSG_TRADE_BLOCKED:format(name or "?"))
    CancelTrade()
end

local function HandleTradeShow()
    local name, realm = UnitName("npc")
    if name then
        EvaluateTrade(name, realm)
        return
    end

    -- Handelt uns jemand anderes an (statt dass wir selbst den Handel starten),
    -- ist der Name der "npc"-Unit im TRADE_SHOW-Moment manchmal noch nicht gesetzt.
    -- Einen Frame später erneut versuchen, statt ohne Meldung "?" auszugeben.
    C_Timer.After(0, function()
        EvaluateTrade(UnitName("npc"))
    end)
end

------------------------------------------------------------
-- Auktionshaus
------------------------------------------------------------

local function CloseAH()
    if C_AuctionHouse and C_AuctionHouse.CloseAuctionHouse then
        C_AuctionHouse.CloseAuctionHouse()
    elseif CloseAuctionHouse then
        CloseAuctionHouse()
    elseif AuctionHouseFrame then
        HideUIPanel(AuctionHouseFrame)
    end
end

local function HandleAuctionShow()
    GroupFound.Print(L.MSG_AH_BLOCKED)
    CloseAH()
end

------------------------------------------------------------
-- Post (Mail)
------------------------------------------------------------

-- Ausgehende Post blockieren
if type(SendMail) == "function" then
    local orig_SendMail = SendMail
    SendMail = function(recipient, subject, body, ...)
        if recipient then
            local n, r = strsplit("-", recipient, 2)
            if not GroupFound.IsWhitelisted(n, r) then
                GroupFound.Print(L.MSG_MAIL_SEND_BLOCKED:format(recipient))
                return
            end
        end
        return orig_SendMail(recipient, subject, body, ...)
    end
end

-- Eingehende Anhänge/Geld von nicht gelisteten Spielern sperren
local function GetInboxSender(index)
    local _, _, sender = GetInboxHeaderInfo(index)
    return sender
end

local function WrapMailTake(fnName)
    local orig = _G[fnName]
    if type(orig) ~= "function" then return end
    _G[fnName] = function(index, ...)
        local sender = GetInboxSender(index)
        if sender then
            local n, r = strsplit("-", sender, 2)
            if not GroupFound.IsWhitelisted(n, r) then
                GroupFound.Print(L.MSG_MAIL_TAKE_BLOCKED:format(sender))
                return
            end
        end
        return orig(index, ...)
    end
end

WrapMailTake("TakeInboxItem")
WrapMailTake("TakeInboxMoney")
WrapMailTake("AutoLootMailItem")

------------------------------------------------------------
-- Events
------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            GroupFound.InitDB()
        end
    elseif event == "PLAYER_LOGIN" then
        -- DB ist zu diesem Zeitpunkt garantiert initialisiert
        GroupFoundDB = GroupFoundDB or {}
        GroupFound.InitDB()
    elseif event == "TRADE_SHOW" then
        HandleTradeShow()
    elseif event == "AUCTION_HOUSE_SHOW" then
        HandleAuctionShow()
    end
end)

------------------------------------------------------------
-- Slash Commands
------------------------------------------------------------

SLASH_GROUPFOUND1 = "/gf"
SLASH_GROUPFOUND2 = "/groupfound"

SlashCmdList["GROUPFOUND"] = function(msg)
    msg = trim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "" then
        GroupFound.ToggleUI()
    elseif cmd == "add" then
        if rest ~= "" then
            if GroupFound.AddName(rest) then
                GroupFound.Print(L.MSG_ADDED:format(trim(rest)))
                GroupFound.RefreshUI()
            end
        else
            -- Kein Name angegeben: aktuelles Ziel verwenden
            GroupFound.AddCurrentTarget()
        end
    elseif (cmd == "remove" or cmd == "del") and rest ~= "" then
        GroupFound.RemoveName(rest)
        GroupFound.Print(L.MSG_REMOVED:format(trim(rest)))
        GroupFound.RefreshUI()
    elseif cmd == "list" then
        local list = GroupFound.GetSortedList()
        if #list == 0 then
            GroupFound.Print(L.MSG_LIST_EMPTY)
        else
            GroupFound.Print(L.MSG_LIST_HEADER:format(#list))
            for _, entry in ipairs(list) do
                DEFAULT_CHAT_FRAME:AddMessage("  - " .. entry.display)
            end
        end
    elseif (cmd == "invite" or cmd == "inv") and rest ~= "" then
        GroupFound.SendInvite(rest)
    elseif cmd == "group" then
        GroupFound.ToggleUI("members")
    else
        GroupFound.Print(L.MSG_USAGE_HEADER)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_TOGGLE)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_ADD)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_ADD_TARGET)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_REMOVE)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_LIST)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_INVITE)
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L.CMD_GROUP)
    end
end
