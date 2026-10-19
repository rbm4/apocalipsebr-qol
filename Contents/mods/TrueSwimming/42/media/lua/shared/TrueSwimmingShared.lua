-- True Swimming — partie COMMUNE : chargee par le solo, par chaque client multijoueur ET par le serveur
-- (media/lua/shared est charge partout : LuaManager.LoadDirBase "shared" puis "client" ; GameServer "shared" puis "server").
-- Contient ce qui doit exister des deux cotes du reseau : la detection de l'eau, LE PONTON INVISIBLE (deblocage des
-- cases d'eau, par proprietaire) et les zombies tenus a terre.
--
-- POURQUOI LES DEUX COTES (lu dans le moteur 42.20.4, le 21/09/2026) :
--  * cote client, la collision du joueur est locale (IsoMovingObject l.839, CollideWithObstaclesPoly) : sans ponton
--    local, le nageur est bloque a la rive ;
--  * cote serveur, l'anti-triche AntiCheatNoClip (option serveur AntiCheatNoClip, actif par defaut) verifie CHAQUE
--    deplacement contre la matrice de chemin du serveur (IsoGridSquare.getPathMatrix) et TELEPORTE EN ARRIERE un joueur
--    qui passe sur une case infranchissable : sans ponton serveur, impossible d'entrer dans l'eau en multi ;
--  * les zombies sont pilotes par le serveur : c'est la qu'il faut les tenir sur la rive (une case d'eau ouverte est
--    franchissable pour eux aussi, PathFindBehavior2 l.1327 : hasFloorOverWater).
-- Le ponton n'est jamais transmis par le reseau (AddTileObject est local, seul transmitAddObjectToSquare envoie) ;
-- chaque cote pose et retire les siens. Un ponton recu dans un chunk (le serveur en avait un au moment de l'envoi)
-- est retire au chargement de la case (LoadGridsquare).

TrueSwimming = TrueSwimming or {}
local TS = TrueSwimming
TS.LOG = false   -- traces console (le fichier client peut le mettre a vrai avec son propre TS_LOG)

-------------------------------------------------------------------------------
-- options sandbox (page TrueSwimming) — SandboxVars existe aussi sur le serveur
-------------------------------------------------------------------------------
function TS.sbv(name, default)
    local t = SandboxVars and SandboxVars.TrueSwimming
    if t then local v = t[name]; if v ~= nil then return v end end
    return default
end
function TS.sbOn(name, default) local v = TS.sbv(name, default); if v == nil then return default end; return v ~= false end
function TS.sbMul(name)
    local m = TS.sbv(name, 1.0)
    if type(m) ~= "number" or m <= 0 then return 1.0 end
    return m
end

-------------------------------------------------------------------------------
-- l'eau
-------------------------------------------------------------------------------
TS.MARK = "TrueSwimming_ponton"
TS.MARK_ID = 380237272   -- identifiant de sprite reserve au mod (schema du mod Ladders : entier unique et fixe)
local MARK, MARK_ID = TS.MARK, TS.MARK_ID

-- une case est de l'eau si un de ses objets porte le drapeau water et qu'aucun autre n'y pose un vrai sol (pont, ponton)
-- — notre ponton invisible ne compte pas comme un sol
function TS.isWater(sq)
    if not sq then return false end
    local objs = sq:getObjects()
    if not objs then return false end
    local hasWater = false
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        local props = obj and obj:getProperties()
        if props and obj:getName() ~= MARK then
            if props:has(IsoFlagType.water) then
                hasWater = true
            elseif props:has(IsoFlagType.solidfloor) then
                return false
            end
        end
    end
    return hasWater
end

-------------------------------------------------------------------------------
-- LE PONTON INVISIBLE
-- Le moteur bloque une case d'eau par le drapeau solidtrans de la CASE, lu par la collision (CalculateCollide), les
-- obstacles polygonaux par chunk (CollideWithObstaclesPoly, marge de 2 cases) et le pathfinder (getBits 0x400,
-- getPathMatrix). Les proprietes d'une case sont RECONSTRUITES depuis les sprites de ses objets a tout moment.
-- Regle du ponton (RecalcProperties, nonWaterSolidFloor) : une case d'eau qui porte, APRES l'objet eau, un objet dont le
-- sprite a solidfloor sans water ni solidtrans perd solidtrans. On pose donc un objet invisible (sprite maison) sur les
-- cases d'eau du 3x3 autour du nageur, et on le retire quand il s'eloigne. AddTileObject / RemoveTileObject
-- reconstruisent la case et ses voisines (RecalcAllWithNeighbours, matrice de chemin comprise) et previennent le
-- pathfinder natif (PolygonalMap2.squareChanged) ; le cache polygonal des chunks voisins est vide a la main.
-------------------------------------------------------------------------------
local function keyOf(sq) return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() end
local function chunkOf(v) return math.floor(v / 8) end

-- le sprite du ponton : le moteur VIDE le gestionnaire de sprites a chaque chargement de monde (IsoWorld.init) puis
-- recharge les tuiles et declenche OnLoadedTileDefinitions — on s'enregistre la (comme le mod Ladders), et on
-- re-verifie par l'identifiant a chaque pose (getSprite(int) rend nil si absent)
local function registerMark()
    local manager = IsoSpriteManager.instance
    if not manager then return false end
    local spr = manager:getSprite(MARK_ID)
    if spr and spr:getName() == MARK and spr:getProperties():has(IsoFlagType.solidfloor) then return true end
    spr = manager:AddSprite(MARK, MARK_ID)
    if not spr then return false end
    spr:setName(MARK)
    local props = spr:getProperties()
    props:set(IsoFlagType.solidfloor)
    props:set(IsoFlagType.invisible)
    props:CreateKeySet()
    if TS.LOG then print("TrueSwimming: sprite du ponton enregistre, id=" .. tostring(spr:getID())) end
    return true
end
Events.OnLoadedTileDefinitions.Add(registerMark)
TS.registerMark = registerMark

-- vide le cache d'obstacles polygonaux des AUTRES chunks dont la marge de 2 cases couvre la case
local function refreshOtherChunks(sq)
    local cell = getCell()
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local cx, cy = chunkOf(x), chunkOf(y)
    local done = {}
    for dx = -2, 2, 2 do
        for dy = -2, 2, 2 do
            local pcx, pcy = chunkOf(x + dx), chunkOf(y + dy)
            local key = pcx .. "," .. pcy
            if (pcx ~= cx or pcy ~= cy) and not done[key] then
                done[key] = true
                local p = cell:getGridSquare(x + dx, y + dy, z)
                if p then p:RecalcProperties() end
            end
        end
    end
end

-- pose le ponton (ajoute en fin de liste, donc apres l'objet eau : la regle du moteur l'exige)
local function openSquare(sq)
    if not registerMark() then return nil end
    local obj = IsoObject.new(sq, MARK, MARK)
    if not obj then return nil end
    sq:AddTileObject(obj)
    refreshOtherChunks(sq)
    if TS.LOG then print("TrueSwimming: ouverte " .. keyOf(sq) .. " solidtrans=" .. tostring(sq:isSolidTrans())) end
    return { sq = sq, obj = obj }
end

-- retire le ponton (si le chunk a ete decharge entre-temps, l'objet n'y est plus : rien a faire)
-- TS 1.9 : si le chunk de la case est deja decharge (sauvegarde en cours de dechargement, serveur), on ne touche a rien :
-- RemoveTileObject lit obj.getSquare().getChunk().loaded et plante sur un chunk nul (rapports Fichin 01/10, The Running Nose 08/10).
local function closeSquare(entry)
    local sq, obj = entry.sq, entry.obj
    if sq:getChunk() == nil then return end
    if obj:getSquare() == sq then sq:RemoveTileObject(obj) end
    refreshOtherChunks(sq)
    if TS.LOG then print("TrueSwimming: refermee " .. keyOf(sq) .. " solidtrans=" .. tostring(sq:isSolidTrans())) end
end

-- une case d'eau voisine est ouverte si on peut y marcher (pas de mur ni de fenetre entre les deux)... OU si la
-- separation est une barriere / rambarde FRANCHISSABLE (HoppableN/W) dans une direction cardinale : c'est le cas du
-- ponton ou du quai avec garde-fou, et de la barriere au bord d'un lac. isWallTo compte les barrieres comme des murs
-- (drapeaux collideN/W), donc sans cette regle la case derriere la barriere restait fermee et le franchissement vers
-- l'eau (fichier client, vaultIntoWater) ne pouvait jamais partir ; en multi le serveur doit l'ouvrir aussi (anti-triche).
local function isPassable(a, b)
    if not a:isWallTo(b) and not a:isWindowTo(b) then return true end
    local dx, dy = b:getX() - a:getX(), b:getY() - a:getY()
    if dx == 0 and dy == -1 then return a:has(IsoFlagType.HoppableN) end   -- b au nord de a
    if dx == -1 and dy == 0 then return a:has(IsoFlagType.HoppableW) end   -- b a l'ouest
    if dx == 0 and dy == 1 then return b:has(IsoFlagType.HoppableN) end    -- b au sud
    if dx == 1 and dy == 0 then return b:has(IsoFlagType.HoppableW) end    -- b a l'est
    return false
end

-- les pontons sont tenus PAR PROPRIETAIRE : un joueur local ("local0"...) ou, sur le serveur, un joueur en ligne
local owners = {}   -- [cle] = { [x,y,z] = { sq = case, obj = ponton } }

local function keysOf(t)
    local keys, n = {}, 0
    for k in pairs(t) do n = n + 1; keys[n] = k end
    return keys, n
end

-- referme tout ce que ce proprietaire tenait
function TS.restoreOwner(key)
    local set = owners[key]
    if not set then return end
    owners[key] = nil
    local n = 0
    for _, entry in pairs(set) do closeSquare(entry); n = n + 1 end
    if TS.LOG and n > 0 then print("TrueSwimming: fin de baignade (" .. tostring(key) .. "), " .. n .. " cases refermees") end
end

-- psq = case du proprietaire (nil = plus actif : tout referme). Ouvre les cases d'eau du 3x3, referme celles qui en
-- sont sorties (le nageur avance : on ne laisse pas une trainee de pontons derriere lui)
function TS.updateClipFor(key, psq)
    if not psq then TS.restoreOwner(key); return end
    local set = owners[key]
    local cell = getCell()
    local px, py, pz = psq:getX(), psq:getY(), psq:getZ()
    local found = false
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(px + dx, py + dy, pz)
            if sq and TS.isWater(sq) and isPassable(psq, sq) then
                found = true
                if not set then set = {}; owners[key] = set end
                local k = keyOf(sq)
                local entry = set[k]
                if entry and (entry.sq ~= sq or entry.obj:getSquare() ~= sq) then
                    closeSquare(entry); set[k] = nil; entry = nil   -- chunk recharge ou objet disparu : on repart proprement
                end
                if not entry then set[k] = openSquare(sq) end
            end
        end
    end
    if not set then return end
    if not found then TS.restoreOwner(key); return end
    local keys, n = keysOf(set)
    for i = 1, n do
        local entry = set[keys[i]]
        local sq = entry.sq
        if sq:getZ() ~= pz or math.abs(sq:getX() - px) > 1 or math.abs(sq:getY() - py) > 1 then
            closeSquare(entry); set[keys[i]] = nil
        end
    end
end

function TS.restoreAll()
    local keys, n = keysOf(owners)
    for i = 1, n do TS.restoreOwner(keys[i]) end
end

-- jamais de ponton dans une sauvegarde
Events.OnSave.Add(TS.restoreAll)

-- ponton orphelin (partie quittee brutalement, ou chunk recu du serveur pendant qu'un nageur y etait) : retire des
-- que sa case se charge
Events.LoadGridsquare.Add(function(sq)
    local objs = sq and sq:getObjects()
    if not objs then return end
    for i = objs:size() - 1, 0, -1 do
        local obj = objs:get(i)
        if obj and obj:getName() == MARK then sq:RemoveTileObject(obj) end
    end
end)

-------------------------------------------------------------------------------
-- L'EAU PEU PROFONDE (moteur d'eau, marche 6, 23/09/2026). Un autre mod (True Water) peut fournir la PROFONDEUR des cases :
-- TS.classeDe = fonction(x, y) -> 0 (terre/inconnu), 1 (eau aux chevilles), 2 (sous la taille), 3+ (profond). Sans lui, tout
-- est profond et le mod se comporte exactement comme sur le Workshop. Regle de Romain : « l'eau a la cheville n'est pas une
-- frontiere ; une vraie frontiere c'est une eau ou il faut nager » -> classes 1 et 2 = on MARCHE (joueur ET zombies, ralentis
-- par les animations), 3+ = on NAGE, les zombies s'arretent. Les cases peu profondes sont ouvertes EN PERMANENCE (ponton
-- invisible tenu par le proprietaire "peuProfond", re-pose a chaque chargement de case, jamais sauvegarde).
-------------------------------------------------------------------------------
TS.classeDe = TS.classeDe or nil
-- classe REELLE d'une case, mesuree sur les VRAIES tuiles (la couleur du shader fait pareil depuis le 23/09) : distance a la
-- vraie terre (voisins a 1 -> chevilles, a 2 -> mi-cuisse, sinon on nage) ; le cadastre ne sert qu'aux PISCINES (classe 8). Memoire par case.
local classeCache = {}
-- PISCINE / bassin construit (meme regle que l'agent MoteurEauPont.piscine, 23/09) : cadastre classe 8, OU eau inconnue du cadastre
-- (classe 0 = pas une riviere/un lac de la carte du monde) dont TOUTES les terres a moins de 2 cases sont construites (carrelage,
-- beton, plancher, piece) et au moins une trouvee. Sol naturel = blends_natural / floors_exterior_natural / blends_grass.
local function solNaturel(q)
    if q:isInARoom() then return false end
    local f = q:getFloor()
    local spr = f and f:getSprite()
    local n = spr and spr:getName()
    if not n then return true end
    return string.sub(n, 1, 14) == "blends_natural" or string.sub(n, 1, 23) == "floors_exterior_natural" or string.sub(n, 1, 12) == "blends_grass"
end
local piscineCache = {}
function TS.piscine(x, y)
    local k = x * 65536 + y
    local c = piscineCache[k]
    if c ~= nil then return c end
    local cl = TS.classeDe(x, y)
    if cl == 8 then piscineCache[k] = true; return true end
    if cl ~= 0 then piscineCache[k] = false; return false end
    local cell = getCell()
    local sq = cell:getGridSquare(x, y, 0)
    if not sq or not TS.isWater(sq) then return false end
    -- rayon 6 (meme regle que l'agent) : le centre d'une piscine n'a aucune terre a moins de 2 cases
    local terre, complet = false, true
    for r = 1, 6 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local q = cell:getGridSquare(x + dx, y + dy, 0)
                    if not q then complet = false
                    elseif not TS.isWater(q) then
                        if solNaturel(q) then piscineCache[k] = false; return false end
                        terre = true
                    end
                end
            end
        end
        if terre and r >= 2 then break end   -- les premieres terres trouvees sont toutes construites : piscine
    end
    if complet then piscineCache[k] = terre end
    return terre
end
function TS.classeReelle(x, y)
    local k = x * 65536 + y
    local c = classeCache[k]
    if c then return c end
    local cell = getCell()
    local sq = cell:getGridSquare(x, y, 0)
    if not sq or not TS.isWater(sq) then return 0 end
    if TS.piscine(x, y) then classeCache[k] = 3; return 3 end   -- piscine / bassin construit : profond des le bord
    c = 3
    for r = 1, 2 do
        for dx = -r, r do
            for dy = -r, r do
                if (math.abs(dx) == r or math.abs(dy) == r) and c == 3 then
                    local n = cell:getGridSquare(x + dx, y + dy, 0)
                    if n and not TS.isWater(n) then c = r end
                end
            end
        end
        if c < 3 then break end
    end
    classeCache[k] = c
    return c
end
function TS.peuProfond(sq)
    if not TS.classeDe or not sq or sq:getZ() ~= 0 then return nil end
    if not TS.isWater(sq) then return nil end
    local cl = TS.classeReelle(sq:getX(), sq:getY())
    if cl == 1 or cl == 2 then return cl end
    return nil
end
local PEU_PROFOND = "peuProfond"
-- PROFONDEUR CONTINUE sous un point (Romain 23/09 : « un truc vraiment progressif de la terre ferme au pataugeage ») : l'enfoncement
-- cible de chaque case (terre 0, BERGE 0,05, chevilles 0,11, mi-cuisse 0,22, eau a nager 0,26) est INTERPOLE bilineairement entre les
-- quatre cases qui entourent la position exacte -> la descente commence sur la derniere case de terre et ne saute jamais.
-- (Romain 23/09 : « a mi-torse alors que ca devrait etre a mi-cuisse ») : le pataugeage ne descend JAMAIS sous la taille ;
--  les cases a nager valent la meme chose que la taille dans l'interpolation, la nage prend le relais en y entrant
-- (23/09, apres la greffe 3 = rendu exact : 1 unite = 2,449/1,5 = 1,63 unite de modele, Bob mesure 0,95, bassin 0,49 -> 0,30 tombait a la
--  HANCHE ; mi-cuisse vrai = 0,35 de modele = 0,22 ; capture de Romain 09h50 : « il s'enfonce beaucoup pres du rivage »)
local ENF_CLASSE = { [0] = 0.0, [1] = 0.11, [2] = 0.22 }   -- chevilles (mi-tibia), MI-CUISSE
-- LA CASE DE BERGE (Romain 23/09, captures 09h18 : « je commence a marcher dans l'eau et je m'enfonce pas de suite ») : le fondu de
-- berge vanilla est dessine sur une case de TERRE (IsoWaterGeometry.init : case sans drapeau water, sol « blends_natural », coins a 1
-- quand une des cases touchant le coin est de l'eau) -> la couleur de l'eau commence UNE case avant la premiere vraie case d'eau,
-- et le corps doit commencer a descendre la aussi. Memes criteres que le moteur ; les 8 voisins doivent etre charges pour memoriser.
local ENF_BERGE = 0.05
local bergeCache = {}
function TS.berge(x, y)
    local k = x * 65536 + y
    local c = bergeCache[k]
    if c ~= nil then return c end
    local cell = getCell()
    local sq = cell:getGridSquare(x, y, 0)
    if not sq or TS.isWater(sq) then return false end
    local floor = sq:getFloor()
    local spr = floor and floor:getSprite()
    local nom = spr and spr:getName()
    if not nom or string.sub(nom, 1, 14) ~= "blends_natural" then bergeCache[k] = false; return false end
    local complet, eau = true, false
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local n = cell:getGridSquare(x + dx, y + dy, 0)
                if not n then complet = false
                elseif TS.isWater(n) and not TS.piscine(x + dx, y + dy) then eau = true end   -- une piscine n'a pas de berge
            end
        end
    end
    if complet then bergeCache[k] = eau end
    return eau
end
local function enfCase(x, y)
    local cl = TS.classeReelle(x, y)
    if cl >= 3 then return 0.26 end   -- haut de cuisse : la nage prend le relais en y entrant
    if cl == 0 then return TS.berge(x, y) and ENF_BERGE or 0.0 end
    return ENF_CLASSE[cl] or 0.0
end
function TS.enfoncementContinu(px, py)
    if not TS.classeDe then return 0.0 end
    local fx, fy = px - 0.5, py - 0.5
    local ix, iy = math.floor(fx), math.floor(fy)
    local tx, ty = fx - ix, fy - iy
    local a = enfCase(ix, iy) * (1 - tx) + enfCase(ix + 1, iy) * tx
    local b = enfCase(ix, iy + 1) * (1 - tx) + enfCase(ix + 1, iy + 1) * tx
    return a * (1 - ty) + b * ty
end
function TS.openShallow(sq)
    local set = owners[PEU_PROFOND]
    if not set then set = {}; owners[PEU_PROFOND] = set end
    local k = keyOf(sq)
    local entry = set[k]
    if entry and (entry.sq ~= sq or entry.obj:getSquare() ~= sq) then set[k] = nil; entry = nil end
    if not entry then set[k] = openSquare(sq) end
end
-- PORTES pour l'eau DYNAMIQUE de True Water (crues / assechement, 06/10/2026) : une case change de nature en cours de partie
function TS.closeShallow(sq)
    local set = owners[PEU_PROFOND]
    if not set then return end
    local k = keyOf(sq)
    local entry = set[k]
    if entry then closeSquare(entry); set[k] = nil end
end
-- oublie les classes / berges mises en cache autour d'une case dont le sol vient de changer (rayon 3 : classeReelle regarde a 2)
function TS.invaliderCase(x, y)
    local dx = -3
    while dx <= 3 do
        local dy = -3
        while dy <= 3 do
            local k = (x + dx) * 65536 + (y + dy)
            classeCache[k] = nil; bergeCache[k] = nil
            dy = dy + 1
        end
        dx = dx + 1
    end
end
Events.LoadGridsquare.Add(function(sq)
    if TS.classeDe and TS.peuProfond(sq) then TS.openShallow(sq) end
end)

-------------------------------------------------------------------------------
-- les zombies ne nagent pas : une case d'eau ouverte est franchissable pour tout le monde, et un zombie ADJACENT peut
-- y entrer par son mouvement direct. Tout zombie surpris sur une case d'eau pres d'un nageur est remis sur la terre
-- ferme la plus proche. Appele par le solo (fichier client) ou par le serveur (fichier serveur) avec la liste des
-- nageurs ; jamais par un client multijoueur (les zombies y sont des copies du serveur).
-------------------------------------------------------------------------------
local function nearestLand(sq)
    local cell = getCell()
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    for r = 1, 3 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local n = cell:getGridSquare(x + dx, y + dy, z)
                    if n and (not TS.isWater(n) or TS.peuProfond(n)) and n:isFree(false) then return n end   -- le peu profond vaut terre ferme
                end
            end
        end
    end
    return nil
end

local zLand = {}   -- [id du zombie] = { x, y } derniere position connue sur la terre ferme (pendant une baignade)
local zLandUsed = false
-- ownedHere : en multi, un zombie n'est deplace que par le cote qui le SIMULE (moteur 42.20.4, NetworkZombieManager.updateAuth :
-- le serveur confie chaque zombie au client le plus proche, de preference celui qu'il poursuit ; ce client fait tourner son IA
-- et son deplacement, le serveur ne fait que suivre ses paquets — NetworkZombieAI.parse remet le zombie sur la position recue).
-- IsoGameCharacter.isLocal() : solo = toujours vrai ; client = vrai pour les zombies que CE client simule ; serveur = vrai pour
-- les zombies confies a un client (que le serveur ne doit donc PAS toucher). Le client passe true, le serveur false.
function TS.keepZombiesAshore(swimmers, n, ownedHere)
    if n == 0 then
        if zLandUsed then zLand = {}; zLandUsed = false end   -- une memoire de rive perimee teleporterait un zombie a la baignade suivante
        return
    end
    local zombies = getCell():getZombieList()
    if not zombies then return end
    if ownedHere == nil then ownedHere = true end
    for i = 0, zombies:size() - 1 do
        local zed = zombies:get(i)
        if zed and not zed:isDead() and zed:isLocal() == ownedHere then
            local near = false
            local zx, zy = zed:getX(), zed:getY()
            for k = 1, n do
                local p = swimmers[k]
                if math.abs(p:getX() - zx) < 8 and math.abs(p:getY() - zy) < 8 then near = true; break end
            end
            -- TS 1.9 : porte pour un autre mod (Sprinters Can Swim) : un zombie autorise a nager n'est pas retenu par le mur
            if near and TS.zombiePeutNager ~= nil and TS.zombiePeutNager(zed) then near = false end
            if near then
                local id = zed:getID()
                local sq = zed:getSquare()
                -- (Romain 23/09 : « pas de tp : il doit rester dans la zone de pataugeage ») : la frontiere des zombies est le bord
                -- de l'eau A NAGER ; le peu profond est a eux, et le mur invisible ne les retient que de quelques centimetres
                if sq and TS.isWater(sq) and not TS.peuProfond(sq) then
                    local last = zLand[id]
                    if last then
                        -- mur invisible : on le ramene a sa derniere position sur la terre (quelques centimetres, pas une case)
                        zed:setX(last[1]); zed:setY(last[2]); zed:setLastX(last[1]); zed:setLastY(last[2])
                    else
                        local land = nearestLand(sq)
                        if land then zed:setX(land:getX() + 0.5); zed:setY(land:getY() + 0.5); zed:setLastX(zed:getX()); zed:setLastY(zed:getY()) end
                    end
                else
                    zLand[id] = { zx, zy }
                    zLandUsed = true
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- les zombies PATAUGENT aussi (Romain 23/09 : « si je patauge il faut que le zombie patauge aussi ») : sur une case peu
-- profonde, un zombie proche d'un joueur est dessine plus bas (variable tw_enfoncement lue par la greffe du moteur d'eau :
-- chevilles 0,11 / sous la taille 0,46, comme les animations du joueur) et ralenti par ses propres noeuds de marche
-- (variable tweau). Sans l'agent, seul le ralentissement joue. Appele avec la liste des joueurs actifs.
-------------------------------------------------------------------------------
local zEau = {}   -- [id] = { orig = speedMod d'origine, zed = zombie }
function TS.zombiesPataugent(players, n, ownedHere)
    if not TS.classeDe then return end
    local zombies = getCell():getZombieList()
    if not zombies then return end
    if ownedHere == nil then ownedHere = true end
    local vus = {}
    for i = 0, zombies:size() - 1 do
        local zed = zombies:get(i)
        if zed and not zed:isDead() and zed:isLocal() == ownedHere then
            local zx, zy = zed:getX(), zed:getY()
            local near = false
            for k = 1, n do
                local p = players[k]
                if p and math.abs(p:getX() - zx) < 14 and math.abs(p:getY() - zy) < 14 then near = true; break end
            end
            if near then
                local id = zed:getID()
                -- profondeur CONTINUE a sa position exacte (comme le joueur) : vaut sur toute case, y compris quand le mur le
                -- retient au bord du profond et que sa case bascule d'une image a l'autre (Romain 23/09 : « il est sur l'eau,
                -- les bras tendus vers moi » -> plus de clignotement)
                local enf = TS.enfoncementContinu(zx, zy)
                if enf > 0.004 then
                    vus[id] = true
                    if not zEau[id] then zEau[id] = { zed = zed } end
                    if math.abs(zed:getVariableFloat("tw_enfoncement", 0) - enf) > 0.004 then zed:setVariable("tw_enfoncement", enf) end
                    -- ralentissement REEL : en B42 la vitesse du zombie = SpeedScale du noeud de marche x root motion (speedMod
                    -- est un vestige) -> nos noeuds AnimSets/zombie/walktoward/tswim_{cheville,taille}.xml (x0,55 / x0,45,
                    -- Zombie_WalkTrees a la taille : pas hauts, bras leves), choisis par la variable STRING tweau
                    -- memes paliers que le joueur (TS 1.8) : cheville (vanilla abaissee 0,26) puis « taille » (0,36) a partir de SEUIL_TAILLE
                    local pal = (enf < (TS.SEUIL_TAILLE or 0.19)) and "cheville" or "taille"
                    if zed:getVariableString("tweau") ~= pal then zed:setVariable("tweau", pal) end
                    -- SONDE zombie (console -debug : TrueSwimming.SONDEZ = true) : etat et noeuds du zombie le plus proche, 2x/s
                    if TS.SONDEZ and (not TS._sondeZT or getTimestampMs() - TS._sondeZT > 500) then
                        TS._sondeZT = getTimestampMs()
                        print(string.format("TSONDEZ id=%d etat=%s tweau=%s enf=%.2f ragdoll=%s | %s", id, tostring(zed:getCurrentStateName()),
                            tostring(zed:getVariableString("tweau")), enf, tostring(zed:isRagdoll()), tostring(zed:getAnimationDebug())))
                    end
                end
            end
        end
    end
    for id, e in pairs(zEau) do
        if not vus[id] then
            local zed = e.zed
            if zed and not zed:isDead() then zed:clearVariable("tw_enfoncement"); zed:clearVariable("tweau") end
            zEau[id] = nil
        end
    end
end

-------------------------------------------------------------------------------
-- mouille comme la pluie le fait (BodyDamage.increaseBodyWetness : parties du corps ; la stat WETNESS suit la moyenne des
-- parties, BodyDamage.UpdateWetness) + vetements portes a 100. Appele par le CLIENT (ses parties du corps, sa stat, son
-- moodle) ET par le SERVEUR en multi : c'est le serveur qui calcule le mouille des VETEMENTS sur sa copie du joueur
-- (BodyDamage.UpdateWetness -> ClothingWetnessSync -> ClothingWetnessPacket, moteur 42.20.4) et qui l'envoie au client
-- des que la valeur entiere change. Sans cet appel cote serveur, sa copie seche au sec et ecrase les 100 du client ;
-- or le corps ne seche que sous une couche de vetement a <= 50 (ClothingWetness.updateWetness, derniere boucle) :
-- vetements secs pousses par le serveur = corps qui seche = moodle Mouille qui clignote (constate en coop le 22/09/2026).
-------------------------------------------------------------------------------
function TS.wetAll(p)
    local bd = p:getBodyDamage()
    if bd then bd:increaseBodyWetness(100) end
    local worn = p:getWornItems()
    if not worn then return end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and item:IsClothing() then item:setWetness(100) end
    end
end

-------------------------------------------------------------------------------
-- la fatigue (formule Aquatsar Yacht Club B42, AquaSwimServer.lua). Ici parce qu'elle sert des deux cotes : le client en
-- solo, le SERVEUR en multi (c'est lui qui tient l'endurance des joueurs : IsoPlayer.updateEndurance ne tourne pas sur
-- un client, et le serveur renvoie sa valeur par SyncPlayerStats / PlayerStats). Traits, moodles, perks, inventaire et
-- vetements existent sur la copie serveur du joueur ; course/sprint y arrivent par NetworkPlayerVariables.
-------------------------------------------------------------------------------
local traitImpact = {
    { CharacterTrait.UNFIT, 1.2 },
    { CharacterTrait.ATHLETIC, 0.8 },
    { CharacterTrait.OVERWEIGHT, 1.1 },
    { CharacterTrait.OBESE, 1.2 },
}
local moodleImpact = {
    { MoodleType.PANIC, 0.2 },
    { MoodleType.DRUNK, 0.2 },
    { MoodleType.TIRED, 0.2 },
    { MoodleType.PAIN, 0.2 },
}
local swimSuits = { "SwimTrunks_Yellow", "SwimTrunks_Red", "SwimTrunks_Blue", "SwimTrunks_Green", "Swimsuit_TINT" }

local function wearsAny(p, types)
    local inv = p:getInventory()
    for i = 1, #types do
        local item = inv:getItemFromType(types[i])
        if item and item:isEquipped() then return true end
    end
    return false
end

function TS.difficulty(p)
    local coeff = TS.sbOn("KnowsSwimming", true) and 1.0 or 2.5
    if wearsAny(p, { "Glasses_SwimmingGoggles" }) then coeff = coeff * 0.9 end
    if wearsAny(p, swimSuits) then coeff = coeff * 0.9 end
    local weight = p:getInventory():getCapacityWeight()
    if weight > 10 then coeff = coeff * (weight / 10) end
    for i = 1, #traitImpact do
        if p:hasTrait(traitImpact[i][1]) then coeff = coeff * traitImpact[i][2] end
    end
    local moodles = p:getMoodles()
    for i = 1, #moodleImpact do
        coeff = coeff + moodleImpact[i][2] * moodles:getMoodleLevel(moodleImpact[i][1])
    end
    local fitness = p:getPerkLevel(Perks.Fitness)
    coeff = coeff * (1.5 - fitness / 10)
    return coeff
end

-- retire l'endurance de « frames » images de brasse (1 image = 1/60 s ; -0,0002 x coeff par image, comme Aquatsar).
-- course (Shift) = brasse x1,4 (noeud run/tswim_brasse) pour x1,5 d'endurance ; sprint (Alt) = x2 pour x2,5
-- competence Natation (perk custom "Swimming") : -5 % de fatigue par niveau, moitie au niveau 10
function TS.swimSkillMul(p)
    if not Perks or not Perks.Swimming then return 1.0 end
    local lvl = p:getPerkLevel(Perks.Swimming)
    if type(lvl) ~= "number" or lvl <= 0 then return 1.0 end
    if lvl > 10 then lvl = 10 end
    return 1.0 - 0.05 * lvl
end
function TS.drain(p, frames)
    local coeff = TS.difficulty(p) * TS.sbMul("StaminaMul") * TS.swimSkillMul(p)
    if p:isSprinting() then coeff = coeff * 2.5 elseif p:isRunning() then coeff = coeff * 1.5 end
    p:getStats():remove(CharacterStat.ENDURANCE, 0.00020 * coeff * frames)
end
