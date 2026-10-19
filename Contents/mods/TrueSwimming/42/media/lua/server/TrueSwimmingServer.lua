-- True Swimming — partie SERVEUR (multijoueur). Chargee par le serveur dedie et par le serveur d'un hote coop
-- (GameServer : "shared" puis "server") ; aussi chargee par le solo et par les clients (GameLoadingState charge "server"),
-- d'ou la garde isServer() : ailleurs ce fichier ne fait rien.
--
-- Ce que le serveur doit faire, et pourquoi (moteur 42.20.4, lu le 21/09/2026) :
--  1. Poser le PONTON INVISIBLE (TrueSwimmingShared) sur les cases d'eau du 3x3 autour de CHAQUE joueur en ligne,
--     depuis la rive deja : l'anti-triche AntiCheatNoClip valide chaque deplacement contre la matrice de chemin du
--     serveur (getPathMatrix) et teleporte en arriere un joueur qui passe sur une case infranchissable. Le client pose
--     les siens de son cote pour sa propre collision ; rien ne transite par le reseau.
--  2. Tenir sur la rive les zombies que le serveur simule lui-meme (aucun client proche). Les zombies proches d'un joueur
--     sont simules par le client de ce joueur (NetworkZombieManager.updateAuth) : c'est le fichier client qui les tient.
--  3. Mouiller sa copie du joueur : le mouille des vetements est calcule par le serveur et pousse au client.
--  4. Retirer l'ENDURANCE de la brasse : en multi, IsoPlayer.updateEndurance ne tourne que sur le serveur, qui renvoie
--     la valeur au client ; une soustraction faite sur le client est ecrasee au paquet suivant.
-- La noyade, les objets perdus, le lavage et les sons restent sur le client du nageur (son inventaire lui appartient ;
-- il lit l'endurance synchronisee) ; l'animation arrive aux autres joueurs par la variable "tswim", inscrite dans la
-- liste des variables repliquees (addVariableToSyncList, fichier client).

if not isServer() then return end

local TS = TrueSwimming

local swimmers = {}
local seen = {}
local ticks = 0
local lastMove = {}   -- par joueur : horodatage (ms) du dernier tick ou il nageait en avancant
local resting = {}    -- par joueur : vrai si C'EST NOUS qui avons pose isResting (planche), pour le retirer proprement

local function keyOf(p) return "srv" .. tostring(p:getOnlineID()) end

local function tick()
    local players = getOnlinePlayers()
    if not players then return end
    local enabled = TS.sbOn("Enabled", true)
    local n = 0
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local key = keyOf(p)
            seen[key] = true
            local sq = p:getSquare()
            local active = enabled and sq ~= nil and not p:isDead() and not p:getVehicle()
            TS.updateClipFor(key, active and sq or nil)
            if active and TS.isWater(sq) then
                n = n + 1; swimmers[n] = p
                -- l'ENDURANCE du nageur : le serveur la tient en multi (voir TS.drain). La cadence du serveur n'est pas
                -- celle du client (boucle a pas variable) : on retire l'equivalent des images de 1/60 s ecoulees depuis
                -- le dernier tick, borne a 6 (une pause du serveur ne doit pas vider la barre d'un coup).
                -- isPlayerMoving = le drapeau « bouge » envoye par le client (NetworkPlayerAI.moving).
                -- FAIRE LA PLANCHE : la variable d'animation tswimPlanche est repliquee (addVariableToSyncList cote client) et
                -- appliquee sur la copie serveur ; on pose isResting ici pour que updateEndurance (serveur) regenere « assis »
                local planche = p:getVariableBoolean("tswimPlanche") == true
                if planche and not resting[key] then p:setIsResting(true); resting[key] = true
                elseif not planche and resting[key] then p:setIsResting(false); resting[key] = nil end
                local nowMs = getTimestampMs()
                if p:isPlayerMoving() then
                    local last = lastMove[key]
                    local frames = 1
                    if last then frames = math.min(6, math.max(0, (nowMs - last) / 16.667)) end
                    lastMove[key] = nowMs
                    if frames > 0 then TS.drain(p, frames) end
                else
                    lastMove[key] = nil
                end
            else
                lastMove[key] = nil
                if resting[key] then p:setIsResting(false); resting[key] = nil end
            end
        end
    end
    -- mouille : le serveur calcule le mouille des vetements sur SA copie du joueur et l'envoie au client (voir TS.wetAll) ;
    -- sa copie ne sait pas qu'elle nage, on la mouille ici chaque seconde
    ticks = ticks + 1
    if ticks % 60 == 0 then for k = 1, n do TS.wetAll(swimmers[k]) end end
    for i = n + 1, #swimmers do swimmers[i] = nil end
    -- joueurs partis depuis le tick precedent : leurs pontons sont refermes
    local gone, g = {}, 0
    for key, v in pairs(seen) do
        if v then seen[key] = false else g = g + 1; gone[g] = key end
    end
    for i = 1, g do TS.restoreOwner(gone[i]); seen[gone[i]] = nil; lastMove[gone[i]] = nil; resting[gone[i]] = nil end
    -- seulement les zombies qu'AUCUN client ne simule (isLocal() faux ici) : les autres sont tenus a terre par leur client
    TS.keepZombiesAshore(swimmers, n, false)
end
Events.OnTick.Add(tick)

Events.OnServerStarted.Add(function()
    if TS.LOG then print("TrueSwimming: serveur pret (pontons + zombies cote serveur)") end
end)
