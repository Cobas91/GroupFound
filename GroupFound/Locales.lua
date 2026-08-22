-- GroupFound Locales
-- Waehlt automatisch die Sprache passend zur aktuellen WoW-Clientsprache (GetLocale()).
-- Fehlende Übersetzungen fallen automatisch auf Englisch zurück.
-- Muss vor Core.lua und UI.lua geladen werden (siehe GroupFound.toc).

GroupFound = GroupFound or {}

local L = {}
GroupFound.L = L

------------------------------------------------------------
-- enUS / enGB (Basis, gleichzeitig Fallback für alle Sprachen)
------------------------------------------------------------

local defaults = {
    SUBTITLE = "Trade whitelist for Hardcore",
    HINT = "Trusted players: can trade/mail with you, and once mutual, share notable finds, bags, bank and professions.",
    PROTECTION_ALWAYS_ON = "Protection is always active and cannot be disabled.",
    LIST_LABEL = "Whitelist",
    COUNT_FMT = "%d players",
    EMPTY_LIST = "No players on the list yet.\nAdd a name below.",
    ADD_BUTTON = "Add",
    ADD_HINT = "Leave empty and click to add your current target.",
    CMD_LABEL = "Commands",
    REMOVE_TOOLTIP = "Remove from list",
    MINIMAP_TOOLTIP = "Left-click: open/close the window\nRight-click: open the members tab",

    CMD_TOGGLE = "/gf - open/close window",
    CMD_ADD = "/gf add <name> - add player",
    CMD_ADD_TARGET = "/gf add - no name: add current target",
    CMD_REMOVE = "/gf remove <name> - remove player",
    CMD_LIST = "/gf list - show list in chat",

    MSG_TRADE_BLOCKED = "Trade with %s is not allowed (not on your list).",
    MSG_AH_BLOCKED = "The auction house is disabled.",
    MSG_MAIL_SEND_BLOCKED = "Mail to %s is not allowed (not on your list).",
    MSG_MAIL_TAKE_BLOCKED = "Attachment/money from %s is blocked (not on your list).",
    MSG_ADDED = "Added: %s",
    MSG_REMOVED = "Removed: %s",
    MSG_LIST_EMPTY = "Your list is empty.",
    MSG_LIST_HEADER = "Whitelist (%d):",
    MSG_USAGE_HEADER = "Usage:",
    MSG_NO_TARGET = "No target selected.",
    MSG_TARGET_NOT_PLAYER = "The current target is not a player.",
    MSG_TARGET_IS_SELF = "You cannot add yourself to the list.",
    MSG_TARGET_NAME_UNKNOWN = "Could not determine the target's name.",

    -- Group / shared find history
    TAB_WHITELIST = "Whitelist",
    TAB_MEMBERS = "Members",
    TAB_HISTORY = "History",

    MEMBERS_EMPTY = "No group yet.\nInvite a fellow player below.",
    HISTORY_EMPTY = "No finds yet.",
    NO_GROUP_YET = "You are not in a group yet.",

    INVITE_BUTTON = "Invite",
    INVITE_HINT = "Enter a player name and click Invite.",
    LEAVE_GROUP_BUTTON = "Leave group",
    LEAVE_GROUP_TOOLTIP = "Leave the group",

    JOINED_AGO_FMT = "joined %s ago",
    FOUND_BY_FMT = "Found by %s",
    ONLINE_STATUS_TOOLTIP = "Approximate presence: green if this member has been heard from recently.",

    TIME_JUST_NOW = "just now",
    TIME_MINUTES_FMT = "%d min ago",
    TIME_HOURS_FMT = "%d h ago",
    TIME_YESTERDAY = "yesterday",
    TIME_DAYS_FMT = "%d days ago",
    GOLD_LABEL = "Gold: %s",
    GOLD_UNKNOWN = "Gold: unknown",
    SECTION_PROFESSIONS_HINT = "Click a profession to show its recipes.",
    SECTION_RECIPES_EMPTY = "No recipes known.",

    POPUP_INVITE_TEXT = "%s invites you to link GroupFound groups.\nMembers automatically see each other's notable finds, bags, bank and professions.",
    POPUP_INVITE_TEXT_WITH_MEMBERS = "%s invites you to a GroupFound group with: %s.\nMembers automatically see each other's rare+ finds, bags, bank and professions.",
    POPUP_ACCEPT = "Accept",
    POPUP_DECLINE = "Decline",

    CMD_INVITE = "/gf invite <name> - invite a player to your group",
    CMD_LEAVE = "/gf leave - leave your current group",
    CMD_GROUP = "/gf group - open the group window",

    MSG_INVITE_SENT = "Invite sent to %s.",
    MSG_INVITE_ACCEPTED = "%s accepted your invite.",
    MSG_INVITE_DECLINED = "%s declined your invite.",
    MSG_ALREADY_IN_GROUP = "You are already in a group. Use /gf leave first.",
    MSG_ALREADY_LINKED = "%s is already in your group.",
    MSG_CANNOT_INVITE_SELF = "You cannot invite yourself.",
    MSG_LEFT_GROUP = "You left the group.",
    MSG_NO_GROUP = "You are not in a group.",

    MEMBER_DETAIL_BACK = "< Back",
    MEMBER_DETAIL_STAND_FMT = "As of %s",
    MEMBER_DETAIL_NO_DATA = "No data received yet.",
    MEMBER_ROW_CLICK_HINT = "Click to view inventory, bank and professions",

    SECTION_INVENTORY = "Inventory",
    SECTION_BANK = "Bank",
    SECTION_PROFESSIONS = "Professions",
    SECTION_INVENTORY_EMPTY = "No inventory data yet.",
    SECTION_BANK_EMPTY = "No bank data yet (bank must be opened at least once).",
    SECTION_PROFESSIONS_EMPTY = "No profession data yet.",
    PROFESSION_LEVEL_FMT = "%s %d/%d",
}

for k, v in pairs(defaults) do
    L[k] = v
end

------------------------------------------------------------
-- Übersetzungen je Client-Sprache (GetLocale())
------------------------------------------------------------

local overrides = {}

overrides.deDE = {
    SUBTITLE = "Handels-Whitelist für Hardcore",
    HINT = "Vertraute Spieler: dürfen mit dir handeln/Post schicken und teilen, sobald gegenseitig, nennenswerte Funde, Taschen, Bank und Berufe.",
    PROTECTION_ALWAYS_ON = "Der Schutz ist immer aktiv und kann nicht deaktiviert werden.",
    LIST_LABEL = "Whitelist",
    COUNT_FMT = "%d Spieler",
    EMPTY_LIST = "Noch keine Spieler auf der Liste.\nUnten einen Namen hinzufügen.",
    ADD_BUTTON = "Hinzufügen",
    ADD_HINT = "Leer lassen und klicken, um dein aktuelles Ziel hinzuzufügen.",
    CMD_LABEL = "Befehle",
    REMOVE_TOOLTIP = "Von der Liste entfernen",
    MINIMAP_TOOLTIP = "Linksklick: Fenster öffnen/schließen\nRechtsklick: Mitglieder-Tab öffnen",

    CMD_TOGGLE = "/gf - Fenster öffnen/schließen",
    CMD_ADD = "/gf add <Name> - Spieler hinzufügen",
    CMD_ADD_TARGET = "/gf add - ohne Namen: aktuelles Ziel hinzufügen",
    CMD_REMOVE = "/gf remove <Name> - Spieler entfernen",
    CMD_LIST = "/gf list - Liste im Chat anzeigen",

    MSG_TRADE_BLOCKED = "Handel mit %s ist nicht erlaubt (nicht auf deiner Liste).",
    MSG_AH_BLOCKED = "Das Auktionshaus ist deaktiviert.",
    MSG_MAIL_SEND_BLOCKED = "Post an %s ist nicht erlaubt (nicht auf deiner Liste).",
    MSG_MAIL_TAKE_BLOCKED = "Anhang/Geld von %s wird blockiert (nicht auf deiner Liste).",
    MSG_ADDED = "Hinzugefügt: %s",
    MSG_REMOVED = "Entfernt: %s",
    MSG_LIST_EMPTY = "Deine Liste ist leer.",
    MSG_LIST_HEADER = "Whitelist (%d):",
    MSG_USAGE_HEADER = "Nutzung:",
    MSG_NO_TARGET = "Kein Ziel ausgewählt.",
    MSG_TARGET_NOT_PLAYER = "Das aktuelle Ziel ist kein Spieler.",
    MSG_TARGET_IS_SELF = "Du kannst dich nicht selbst zur Liste hinzufügen.",
    MSG_TARGET_NAME_UNKNOWN = "Name des Ziels konnte nicht ermittelt werden.",

    -- Gruppe / gemeinsame Fund-Historie
    TAB_WHITELIST = "Whitelist",
    TAB_MEMBERS = "Mitglieder",
    TAB_HISTORY = "Historie",

    MEMBERS_EMPTY = "Noch keine Gruppe.\nLade unten einen Mitspieler ein.",
    HISTORY_EMPTY = "Noch keine Funde.",
    NO_GROUP_YET = "Du bist noch in keiner Gruppe.",

    INVITE_BUTTON = "Einladen",
    INVITE_HINT = "Spielername eingeben und auf Einladen klicken.",
    LEAVE_GROUP_BUTTON = "Gruppe verlassen",
    LEAVE_GROUP_TOOLTIP = "Die Gruppe verlassen",

    JOINED_AGO_FMT = "beigetreten vor %s",
    FOUND_BY_FMT = "Gefunden von %s",
    ONLINE_STATUS_TOOLTIP = "Näherungswert: grün, wenn zuletzt vor kurzem etwas von diesem Mitglied empfangen wurde.",

    TIME_JUST_NOW = "gerade eben",
    TIME_MINUTES_FMT = "vor %d Min",
    TIME_HOURS_FMT = "vor %d Std",
    TIME_YESTERDAY = "gestern",
    TIME_DAYS_FMT = "vor %d Tagen",
    GOLD_LABEL = "Gold: %s",
    GOLD_UNKNOWN = "Gold: unbekannt",
    SECTION_PROFESSIONS_HINT = "Beruf anklicken, um die Rezepte anzuzeigen.",
    SECTION_RECIPES_EMPTY = "Keine Rezepte bekannt.",

    POPUP_INVITE_TEXT = "%s lädt dich zu einer GroupFound-Gruppe ein.\nMitglieder sehen automatisch gegenseitig ihre nennenswerten Funde, Taschen, Bank und Berufe.",
    POPUP_INVITE_TEXT_WITH_MEMBERS = "%s lädt dich zu einer GroupFound-Gruppe ein mit: %s.\nMitglieder sehen automatisch gegenseitig ihre Rare+-Funde, Taschen, Bank und Berufe.",
    POPUP_ACCEPT = "Annehmen",
    POPUP_DECLINE = "Ablehnen",

    CMD_INVITE = "/gf invite <Name> - Spieler in deine Gruppe einladen",
    CMD_LEAVE = "/gf leave - deine aktuelle Gruppe verlassen",
    CMD_GROUP = "/gf group - Gruppenfenster öffnen",

    MSG_INVITE_SENT = "Einladung an %s gesendet.",
    MSG_INVITE_ACCEPTED = "%s hat deine Einladung angenommen.",
    MSG_INVITE_DECLINED = "%s hat deine Einladung abgelehnt.",
    MSG_ALREADY_IN_GROUP = "Du bist bereits in einer Gruppe. Nutze zuerst /gf leave.",
    MSG_ALREADY_LINKED = "%s ist bereits in deiner Gruppe.",
    MSG_CANNOT_INVITE_SELF = "Du kannst dich nicht selbst einladen.",
    MSG_LEFT_GROUP = "Du hast die Gruppe verlassen.",
    MSG_NO_GROUP = "Du bist in keiner Gruppe.",

    MEMBER_DETAIL_BACK = "< Zurück",
    MEMBER_DETAIL_STAND_FMT = "Stand: %s",
    MEMBER_DETAIL_NO_DATA = "Noch keine Daten empfangen.",
    MEMBER_ROW_CLICK_HINT = "Klicken für Inventar, Bank und Berufe",

    SECTION_INVENTORY = "Inventar",
    SECTION_BANK = "Bank",
    SECTION_PROFESSIONS = "Berufe",
    SECTION_INVENTORY_EMPTY = "Noch keine Inventar-Daten.",
    SECTION_BANK_EMPTY = "Noch keine Bank-Daten (Bank muss mindestens einmal geöffnet worden sein).",
    SECTION_PROFESSIONS_EMPTY = "Noch keine Berufs-Daten.",
    PROFESSION_LEVEL_FMT = "%s %d/%d",
}

overrides.frFR = {
    SUBTITLE = "Liste blanche d'échange pour Hardcore",
    HINT = "Seuls les joueurs de cette liste peuvent échanger avec vous, vous envoyer du courrier ou recevoir vos pièces jointes.",
    PROTECTION_ALWAYS_ON = "La protection est toujours active et ne peut pas être désactivée.",
    LIST_LABEL = "Liste blanche",
    COUNT_FMT = "%d joueurs",
    EMPTY_LIST = "Aucun joueur dans la liste pour le moment.\nAjoutez un nom ci-dessous.",
    ADD_BUTTON = "Ajouter",
    ADD_HINT = "Laissez vide et cliquez pour ajouter votre cible actuelle.",
    CMD_LABEL = "Commandes",
    REMOVE_TOOLTIP = "Retirer de la liste",
    MINIMAP_TOOLTIP = "Clic gauche : ouvrir/fermer la fenêtre de liste blanche",

    CMD_TOGGLE = "/gf - ouvrir/fermer la fenêtre",
    CMD_ADD = "/gf add <nom> - ajouter un joueur",
    CMD_ADD_TARGET = "/gf add - sans nom : ajoute la cible actuelle",
    CMD_REMOVE = "/gf remove <nom> - retirer un joueur",
    CMD_LIST = "/gf list - afficher la liste dans le chat",

    MSG_TRADE_BLOCKED = "L'échange avec %s n'est pas autorisé (absent de votre liste).",
    MSG_AH_BLOCKED = "L'hôtel des ventes est désactivé.",
    MSG_MAIL_SEND_BLOCKED = "Le courrier vers %s n'est pas autorisé (absent de votre liste).",
    MSG_MAIL_TAKE_BLOCKED = "Pièce jointe/argent de %s bloqué (absent de votre liste).",
    MSG_ADDED = "Ajouté : %s",
    MSG_REMOVED = "Retiré : %s",
    MSG_LIST_EMPTY = "Votre liste est vide.",
    MSG_LIST_HEADER = "Liste blanche (%d) :",
    MSG_USAGE_HEADER = "Utilisation :",
    MSG_NO_TARGET = "Aucune cible sélectionnée.",
    MSG_TARGET_NOT_PLAYER = "La cible actuelle n'est pas un joueur.",
    MSG_TARGET_IS_SELF = "Vous ne pouvez pas vous ajouter vous-même à la liste.",
    MSG_TARGET_NAME_UNKNOWN = "Impossible de déterminer le nom de la cible.",
}

overrides.esES = {
    SUBTITLE = "Lista blanca de comercio para Hardcore",
    HINT = "Solo los jugadores de esta lista pueden comerciar contigo, enviarte correo o recibir tus archivos adjuntos.",
    PROTECTION_ALWAYS_ON = "La protección siempre está activa y no se puede desactivar.",
    LIST_LABEL = "Lista blanca",
    COUNT_FMT = "%d jugadores",
    EMPTY_LIST = "Aún no hay jugadores en la lista.\nAñade un nombre abajo.",
    ADD_BUTTON = "Añadir",
    ADD_HINT = "Déjalo vacío y haz clic para añadir tu objetivo actual.",
    CMD_LABEL = "Comandos",
    REMOVE_TOOLTIP = "Quitar de la lista",
    MINIMAP_TOOLTIP = "Clic izquierdo: abrir/cerrar la ventana de la lista blanca",

    CMD_TOGGLE = "/gf - abrir/cerrar ventana",
    CMD_ADD = "/gf add <nombre> - añadir jugador",
    CMD_ADD_TARGET = "/gf add - sin nombre: añade el objetivo actual",
    CMD_REMOVE = "/gf remove <nombre> - quitar jugador",
    CMD_LIST = "/gf list - mostrar la lista en el chat",

    MSG_TRADE_BLOCKED = "No se permite comerciar con %s (no está en tu lista).",
    MSG_AH_BLOCKED = "La casa de subastas está desactivada.",
    MSG_MAIL_SEND_BLOCKED = "No se permite enviar correo a %s (no está en tu lista).",
    MSG_MAIL_TAKE_BLOCKED = "Se bloquea el adjunto/dinero de %s (no está en tu lista).",
    MSG_ADDED = "Añadido: %s",
    MSG_REMOVED = "Eliminado: %s",
    MSG_LIST_EMPTY = "Tu lista está vacía.",
    MSG_LIST_HEADER = "Lista blanca (%d):",
    MSG_USAGE_HEADER = "Uso:",
    MSG_NO_TARGET = "No hay ningún objetivo seleccionado.",
    MSG_TARGET_NOT_PLAYER = "El objetivo actual no es un jugador.",
    MSG_TARGET_IS_SELF = "No puedes añadirte a ti mismo a la lista.",
    MSG_TARGET_NAME_UNKNOWN = "No se pudo determinar el nombre del objetivo.",
}

overrides.esMX = overrides.esES

overrides.ptBR = {
    SUBTITLE = "Lista branca de comércio para Hardcore",
    HINT = "Somente jogadores desta lista podem negociar com você, enviar correio ou receber anexos seus.",
    PROTECTION_ALWAYS_ON = "A proteção está sempre ativa e não pode ser desativada.",
    LIST_LABEL = "Lista branca",
    COUNT_FMT = "%d jogadores",
    EMPTY_LIST = "Ainda não há jogadores na lista.\nAdicione um nome abaixo.",
    ADD_BUTTON = "Adicionar",
    ADD_HINT = "Deixe vazio e clique para adicionar seu alvo atual.",
    CMD_LABEL = "Comandos",
    REMOVE_TOOLTIP = "Remover da lista",
    MINIMAP_TOOLTIP = "Clique esquerdo: abrir/fechar a janela da lista branca",

    CMD_TOGGLE = "/gf - abrir/fechar janela",
    CMD_ADD = "/gf add <nome> - adicionar jogador",
    CMD_ADD_TARGET = "/gf add - sem nome: adiciona o alvo atual",
    CMD_REMOVE = "/gf remove <nome> - remover jogador",
    CMD_LIST = "/gf list - mostrar lista no chat",

    MSG_TRADE_BLOCKED = "Comércio com %s não é permitido (não está na sua lista).",
    MSG_AH_BLOCKED = "A casa de leilões está desativada.",
    MSG_MAIL_SEND_BLOCKED = "Correio para %s não é permitido (não está na sua lista).",
    MSG_MAIL_TAKE_BLOCKED = "Anexo/dinheiro de %s bloqueado (não está na sua lista).",
    MSG_ADDED = "Adicionado: %s",
    MSG_REMOVED = "Removido: %s",
    MSG_LIST_EMPTY = "Sua lista está vazia.",
    MSG_LIST_HEADER = "Lista branca (%d):",
    MSG_USAGE_HEADER = "Uso:",
    MSG_NO_TARGET = "Nenhum alvo selecionado.",
    MSG_TARGET_NOT_PLAYER = "O alvo atual não é um jogador.",
    MSG_TARGET_IS_SELF = "Você não pode adicionar a si mesmo à lista.",
    MSG_TARGET_NAME_UNKNOWN = "Não foi possível determinar o nome do alvo.",
}

overrides.itIT = {
    SUBTITLE = "Lista bianca degli scambi per Hardcore",
    HINT = "Solo i giocatori in questa lista possono scambiare con te, inviarti posta o ricevere i tuoi allegati.",
    PROTECTION_ALWAYS_ON = "La protezione è sempre attiva e non può essere disattivata.",
    LIST_LABEL = "Lista bianca",
    COUNT_FMT = "%d giocatori",
    EMPTY_LIST = "Nessun giocatore nella lista.\nAggiungi un nome qui sotto.",
    ADD_BUTTON = "Aggiungi",
    ADD_HINT = "Lascia vuoto e clicca per aggiungere il tuo bersaglio attuale.",
    CMD_LABEL = "Comandi",
    REMOVE_TOOLTIP = "Rimuovi dalla lista",
    MINIMAP_TOOLTIP = "Clic sinistro: apri/chiudi la finestra della lista bianca",

    CMD_TOGGLE = "/gf - apri/chiudi finestra",
    CMD_ADD = "/gf add <nome> - aggiungi giocatore",
    CMD_ADD_TARGET = "/gf add - senza nome: aggiunge il bersaglio attuale",
    CMD_REMOVE = "/gf remove <nome> - rimuovi giocatore",
    CMD_LIST = "/gf list - mostra la lista in chat",

    MSG_TRADE_BLOCKED = "Lo scambio con %s non è consentito (non è nella tua lista).",
    MSG_AH_BLOCKED = "La casa d'aste è disattivata.",
    MSG_MAIL_SEND_BLOCKED = "L'invio di posta a %s non è consentito (non è nella tua lista).",
    MSG_MAIL_TAKE_BLOCKED = "Allegato/denaro da %s bloccato (non è nella tua lista).",
    MSG_ADDED = "Aggiunto: %s",
    MSG_REMOVED = "Rimosso: %s",
    MSG_LIST_EMPTY = "La tua lista è vuota.",
    MSG_LIST_HEADER = "Lista bianca (%d):",
    MSG_USAGE_HEADER = "Utilizzo:",
    MSG_NO_TARGET = "Nessun bersaglio selezionato.",
    MSG_TARGET_NOT_PLAYER = "Il bersaglio attuale non è un giocatore.",
    MSG_TARGET_IS_SELF = "Non puoi aggiungere te stesso alla lista.",
    MSG_TARGET_NAME_UNKNOWN = "Impossibile determinare il nome del bersaglio.",
}

overrides.ruRU = {
    SUBTITLE = "Белый список торговли для Хардкора",
    HINT = "Торговать с вами, отправлять вам почту или получать от вас вложения могут только игроки из этого списка.",
    PROTECTION_ALWAYS_ON = "Защита всегда активна и не может быть отключена.",
    LIST_LABEL = "Белый список",
    COUNT_FMT = "Игроков: %d",
    EMPTY_LIST = "В списке пока нет игроков.\nДобавьте имя ниже.",
    ADD_BUTTON = "Добавить",
    ADD_HINT = "Оставьте поле пустым и нажмите, чтобы добавить текущую цель.",
    CMD_LABEL = "Команды",
    REMOVE_TOOLTIP = "Удалить из списка",
    MINIMAP_TOOLTIP = "Левый клик: открыть/закрыть окно белого списка",

    CMD_TOGGLE = "/gf - открыть/закрыть окно",
    CMD_ADD = "/gf add <имя> - добавить игрока",
    CMD_ADD_TARGET = "/gf add - без имени: добавить текущую цель",
    CMD_REMOVE = "/gf remove <имя> - удалить игрока",
    CMD_LIST = "/gf list - показать список в чате",

    MSG_TRADE_BLOCKED = "Торговля с %s запрещена (нет в вашем списке).",
    MSG_AH_BLOCKED = "Аукцион отключён.",
    MSG_MAIL_SEND_BLOCKED = "Отправка почты игроку %s запрещена (нет в вашем списке).",
    MSG_MAIL_TAKE_BLOCKED = "Вложение/деньги от %s заблокированы (нет в вашем списке).",
    MSG_ADDED = "Добавлено: %s",
    MSG_REMOVED = "Удалено: %s",
    MSG_LIST_EMPTY = "Ваш список пуст.",
    MSG_LIST_HEADER = "Белый список (%d):",
    MSG_USAGE_HEADER = "Использование:",
    MSG_NO_TARGET = "Цель не выбрана.",
    MSG_TARGET_NOT_PLAYER = "Текущая цель не является игроком.",
    MSG_TARGET_IS_SELF = "Вы не можете добавить себя в список.",
    MSG_TARGET_NAME_UNKNOWN = "Не удалось определить имя цели.",
}

overrides.koKR = {
    SUBTITLE = "하드코어를 위한 거래 화이트리스트",
    HINT = "이 목록에 있는 플레이어만 당신과 거래하거나, 우편을 보내거나, 첨부물을 받을 수 있습니다.",
    PROTECTION_ALWAYS_ON = "보호 기능은 항상 활성화되어 있으며 비활성화할 수 없습니다.",
    LIST_LABEL = "화이트리스트",
    COUNT_FMT = "플레이어 %d명",
    EMPTY_LIST = "아직 목록에 플레이어가 없습니다.\n아래에 이름을 추가하세요.",
    ADD_BUTTON = "추가",
    ADD_HINT = "비워두고 클릭하면 현재 대상이 추가됩니다.",
    CMD_LABEL = "명령어",
    REMOVE_TOOLTIP = "목록에서 제거",
    MINIMAP_TOOLTIP = "왼쪽 클릭: 화이트리스트 창 열기/닫기",

    CMD_TOGGLE = "/gf - 창 열기/닫기",
    CMD_ADD = "/gf add <이름> - 플레이어 추가",
    CMD_ADD_TARGET = "/gf add - 이름 없이: 현재 대상 추가",
    CMD_REMOVE = "/gf remove <이름> - 플레이어 제거",
    CMD_LIST = "/gf list - 채팅에 목록 표시",

    MSG_TRADE_BLOCKED = "%s 님과의 거래는 허용되지 않습니다 (목록에 없음).",
    MSG_AH_BLOCKED = "경매장이 비활성화되어 있습니다.",
    MSG_MAIL_SEND_BLOCKED = "%s 님에게 우편을 보낼 수 없습니다 (목록에 없음).",
    MSG_MAIL_TAKE_BLOCKED = "%s 님의 첨부물/돈이 차단되었습니다 (목록에 없음).",
    MSG_ADDED = "추가됨: %s",
    MSG_REMOVED = "제거됨: %s",
    MSG_LIST_EMPTY = "목록이 비어 있습니다.",
    MSG_LIST_HEADER = "화이트리스트 (%d):",
    MSG_USAGE_HEADER = "사용법:",
    MSG_NO_TARGET = "대상이 선택되지 않았습니다.",
    MSG_TARGET_NOT_PLAYER = "현재 대상은 플레이어가 아닙니다.",
    MSG_TARGET_IS_SELF = "자기 자신은 목록에 추가할 수 없습니다.",
    MSG_TARGET_NAME_UNKNOWN = "대상의 이름을 확인할 수 없습니다.",
}

overrides.zhCN = {
    SUBTITLE = "硬核模式交易白名单",
    HINT = "只有名单上的玩家才能与你交易、给你寄信或接收你的邮件附件。",
    PROTECTION_ALWAYS_ON = "保护始终处于启用状态，无法关闭。",
    LIST_LABEL = "白名单",
    COUNT_FMT = "%d 名玩家",
    EMPTY_LIST = "名单中还没有玩家。\n在下方添加一个名字。",
    ADD_BUTTON = "添加",
    ADD_HINT = "留空并点击即可添加当前目标。",
    CMD_LABEL = "命令",
    REMOVE_TOOLTIP = "从名单中移除",
    MINIMAP_TOOLTIP = "左键点击：打开/关闭白名单窗口",

    CMD_TOGGLE = "/gf - 打开/关闭窗口",
    CMD_ADD = "/gf add <名字> - 添加玩家",
    CMD_ADD_TARGET = "/gf add - 不填名字：添加当前目标",
    CMD_REMOVE = "/gf remove <名字> - 移除玩家",
    CMD_LIST = "/gf list - 在聊天框显示名单",

    MSG_TRADE_BLOCKED = "不允许与 %s 交易（不在你的名单中）。",
    MSG_AH_BLOCKED = "拍卖行已被禁用。",
    MSG_MAIL_SEND_BLOCKED = "不允许给 %s 寄信（不在你的名单中）。",
    MSG_MAIL_TAKE_BLOCKED = "已屏蔽来自 %s 的附件/金钱（不在你的名单中）。",
    MSG_ADDED = "已添加：%s",
    MSG_REMOVED = "已移除：%s",
    MSG_LIST_EMPTY = "你的名单是空的。",
    MSG_LIST_HEADER = "白名单（%d）：",
    MSG_USAGE_HEADER = "用法：",
    MSG_NO_TARGET = "未选择目标。",
    MSG_TARGET_NOT_PLAYER = "当前目标不是玩家。",
    MSG_TARGET_IS_SELF = "你不能把自己添加到名单中。",
    MSG_TARGET_NAME_UNKNOWN = "无法确定目标的名字。",
}

overrides.zhTW = {
    SUBTITLE = "硬核模式交易白名單",
    HINT = "只有名單上的玩家才能與你交易、寄信給你或接收你的郵件附件。",
    PROTECTION_ALWAYS_ON = "保護一律處於啟用狀態，無法關閉。",
    LIST_LABEL = "白名單",
    COUNT_FMT = "%d 名玩家",
    EMPTY_LIST = "名單中還沒有玩家。\n請在下方新增一個名字。",
    ADD_BUTTON = "新增",
    ADD_HINT = "留空並點擊即可新增目前的目標。",
    CMD_LABEL = "指令",
    REMOVE_TOOLTIP = "從名單中移除",
    MINIMAP_TOOLTIP = "左鍵點擊：開啟/關閉白名單視窗",

    CMD_TOGGLE = "/gf - 開啟/關閉視窗",
    CMD_ADD = "/gf add <名字> - 新增玩家",
    CMD_ADD_TARGET = "/gf add - 不輸入名字：新增目前的目標",
    CMD_REMOVE = "/gf remove <名字> - 移除玩家",
    CMD_LIST = "/gf list - 在聊天視窗顯示名單",

    MSG_TRADE_BLOCKED = "不允許與 %s 交易（不在你的名單中）。",
    MSG_AH_BLOCKED = "拍賣場已被停用。",
    MSG_MAIL_SEND_BLOCKED = "不允許寄信給 %s（不在你的名單中）。",
    MSG_MAIL_TAKE_BLOCKED = "已封鎖來自 %s 的附件/金錢（不在你的名單中）。",
    MSG_ADDED = "已新增：%s",
    MSG_REMOVED = "已移除：%s",
    MSG_LIST_EMPTY = "你的名單是空的。",
    MSG_LIST_HEADER = "白名單（%d）：",
    MSG_USAGE_HEADER = "用法：",
    MSG_NO_TARGET = "未選擇目標。",
    MSG_TARGET_NOT_PLAYER = "目前的目標不是玩家。",
    MSG_TARGET_IS_SELF = "你不能把自己新增到名單中。",
    MSG_TARGET_NAME_UNKNOWN = "無法確定目標的名字。",
}

local locale = GetLocale()
local t = overrides[locale]
if t then
    for k, v in pairs(t) do
        L[k] = v
    end
end
