-- True Swimming v0.5 — le survivant sait nager. Solo et multijoueur.
-- Recette : deblocage des cases d'eau par le PONTON INVISIBLE (un objet de sol invisible pose sur chaque case du 3x3
-- pendant la baignade : la regle du ponton du moteur retire solidtrans de CETTE case seule ; voir la section deblocage),
-- formule de fatigue Aquatsar B42 reprise telle quelle, animations de nage maison
-- (Bob_Nage_Brasse / Bob_Nage_Surplace, noeuds AnimSets conditionnes par la variable d'animation "tswim").
-- Toutes les API citees ont ete verifiees dans projectzomboid.jar 42.20.4 (voir D:\PZ_LABO\nage_etude).
-- MULTIJOUEUR (21/09/2026) : ce fichier tourne sur le client de chaque joueur (solo compris). La partie commune
-- (eau, ponton, zombies) est dans shared/TrueSwimmingShared.lua ; le serveur a server/TrueSwimmingServer.lua.
-- La variable d'animation "tswim" est inscrite dans la liste des variables repliquees aux autres joueurs
-- (VariableSyncPacket.syncedVariables, via le global Lua addVariableToSyncList que le moniteur d'animation du jeu
-- utilise) : IsoGameCharacter.setVariable l'envoie au serveur, qui la garde sur sa copie du joueur et la relaie.
require "TrueSwimmingShared"
require "ISUI/ISPanel"
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISJoystickButtonRadialMenu"

TrueSwimming = TrueSwimming or {}
local TS = TrueSwimming
local VAR = "tswim"

-------------------------------------------------------------------------------
-- options sandbox (page TrueSwimming)
-------------------------------------------------------------------------------
local sbv, sbOn, sbMul = TS.sbv, TS.sbOn, TS.sbMul

-------------------------------------------------------------------------------
-- options du mod (PZAPI.ModOptions, page Options > Mods) : volume des sons de nage
-------------------------------------------------------------------------------
-- Les clips .ogg d'un mod sont joues par FMODSoundEmitter.addSound dans le groupe de canaux "InGameNonBank", dont le
-- volume reste a 1 : le curseur "Sons" du jeu ne pilote que le VCA Settings_Sfx des banques (SoundManager.setSoundVolume),
-- il n'a donc AUCUN effet sur nos sons (constate par les joueurs, 22-25/09/2026). On applique nous-memes
-- curseur "Sons" x curseur du mod, par emitter:setVolume(poignee, v) : la valeur est conservee par l'instance
-- (Sound.volume, relue a chaque image dans getVolume) jusqu'a la fin du son.
local OPT_ID, OPT_VOL = "TrueSwimming", "TSWIM_Volume"
local function setupOptions()
    if not PZAPI or not PZAPI.ModOptions then return end
    local options = PZAPI.ModOptions:create(OPT_ID, "True Swimming")
    options:addTitle("True Swimming")
    options:addSlider(OPT_VOL, getText("UI_options_TSWIM_Volume"), 0, 100, 5, 100, getText("UI_options_TSWIM_Volume_tooltip"))
end
setupOptions()
local function soundVolume()
    local v = 1.0
    local core = getCore()
    if core and core.getRealOptionSoundVolume then v = core:getRealOptionSoundVolume() end   -- curseur "Sons" (0..1)
    if PZAPI and PZAPI.ModOptions then
        local options = PZAPI.ModOptions:getOptions(OPT_ID)
        local opt = options and options:getOption(OPT_VOL)
        local m = opt and opt:getValue()
        if type(m) == "number" then v = v * (m / 100) end
    end
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    return v
end
TS.soundVolume = soundVolume
local function playSound(emitter, name)
    local handle = emitter:playSound(name)
    if handle then emitter:setVolume(handle, soundVolume()) end
    return handle
end

-------------------------------------------------------------------------------
-- l'eau
-------------------------------------------------------------------------------
-- TS.isWater : voir TrueSwimmingShared.lua
function TS.isSwimming(p)
    if not p or p:isDead() or p:getVehicle() then return false end
    local sq = p:getSquare()
    return TS.isWater(sq) and not TS.peuProfond(sq)
end
-- eau peu profonde (True Water fournit la profondeur) : 1 = chevilles, 2 = sous la taille, nil = pas en train de patauger
function TS.isWading(p)
    if not p or p:isDead() or p:getVehicle() then return nil end
    return TS.peuProfond(p:getSquare())
end
-- paliers de pataugeage (TS 1.8) : enfoncement continu (berge 0,05 / chevilles 0,11 / mi-cuisse 0,22) -> e1 | e2 | taille
TS.SEUIL_TAILLE = 0.19  -- en dessous : « cheville » (vanilla descendue de 0,16, des la premiere case d'eau) ; au-dessus : pose « sous la taille »
-- Hauteurs des animations de nage (TS 1.8, calibrees en jeu avec Romain le 06/10/2026, unites jeu, poitrine) : brasse -0,39,
-- surplace -0,40, crawl -0,38, planche -0,27, pose « sous la taille » 0,36 ; scripts dans D:\PZ_LABO\nage_etude\anims_validees.

-------------------------------------------------------------------------------
-- deblocage des cases d'eau : LE PONTON INVISIBLE (mecanique complete dans TrueSwimmingShared.lua). Ici : un
-- proprietaire de pontons par joueur local. En multi, le serveur pose les siens pour l'anti-triche et les zombies.
-------------------------------------------------------------------------------
local TS_LOG = false   -- true = traces console + options de test (clic droit dans l eau) ; false pour la publication
TS.LOG = TS_LOG
local VAR_SYNCED = false
local function syncVar()
    -- en multi : "tswim" repliquee aux autres clients (idempotent, HashSet cote moteur)
    if isClient() and not VAR_SYNCED and addVariableToSyncList then addVariableToSyncList(VAR); addVariableToSyncList("tswimPlanche"); addVariableToSyncList("hweau"); VAR_SYNCED = true end
end
syncVar()
Events.OnGameStart.Add(syncVar)

local function clipKey(i) return "local" .. i end
local function restoreAll()
    for i = 0, getNumActivePlayers() - 1 do TS.restoreOwner(clipKey(i)) end
end

-- compatibilite Aquatsar Yacht Club B42 (3646414716, verifie sur sa version du 20/09/2026 qui delegue la nage a True
-- Swimming) : son detecteur d'eau AquatsarYachts.Swim.isWater (shared/AquaSwimShared.lua), utilise par TOUT son code de
-- bateaux (physique, cale du moteur sur le sol, montee a bord, remorque), dit « pas de l'eau » devant un objet de sol qui
-- n'est pas de l'eau — c'est exactement notre ponton. Un bateau colle au nageur verrait du sol sous lui. On remplace
-- leur detecteur par le notre : meme regle, ponton ignore. Notre fichier se charge apres le leur (LuaManager.LoadDirBase :
-- les shared/ de tous les mods, puis les client/), et on repasse a OnGameBoot par securite.
local function patchAquatsar()
    if AquatsarYachts and AquatsarYachts.Swim and AquatsarYachts.Swim.isWater and AquatsarYachts.Swim.isWater ~= TS.isWater then
        AquatsarYachts.Swim.isWater = TS.isWater
        if TS_LOG then print("TrueSwimming: detecteur d'eau d'Aquatsar remplace (ponton ignore)") end
    end
end
patchAquatsar()
Events.OnGameBoot.Add(patchAquatsar)

-------------------------------------------------------------------------------
-- la fatigue (formule Aquatsar Yacht Club B42, AquaSwimServer.lua)
-------------------------------------------------------------------------------
-- (traits, moodles, maillots, TS.difficulty : deplaces dans TrueSwimmingShared.lua, le serveur en a besoin en multi)

local damagable = {
    BodyPartType.Torso_Upper, BodyPartType.Torso_Lower,
    BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
    BodyPartType.UpperArm_L, BodyPartType.UpperArm_R,
}

local function compareWeight(a, b) return a:getWeight() > b:getWeight() end

-- perd jusqu'a 40 % des objets, les plus lourds d'abord, jamais ce qui est equipe, jusqu'a repasser sous 10 kg
function TS.dropItems(p)
    local inv = p:getInventory()
    local items = {}
    local list = inv:getItems()
    for i = 0, list:size() - 1 do items[#items + 1] = list:get(i) end
    local n = math.floor(#items * 0.4)
    if n < 1 then return end
    local dropNum = ZombRand(n)
    table.sort(items, compareWeight)
    for i = 1, dropNum do
        if items[i] and not items[i]:isEquipped() then
            inv:DoRemoveItem(items[i])
        end
        if inv:getCapacityWeight() < 10 then break end
    end
    p:Say(getText("UI_TSWIM_ItemsSink"))
end

local said = 0
local function now() if getTimestampMs then return getTimestampMs() end return 0 end
local function saySometimes(p, text, chancePerMille)
    if ZombRand(1000) < chancePerMille and now() - said > 6000 then
        said = now()
        p:Say(text)
    end
end

local enduranceWords = { "UI_TSWIM_Tired1", "UI_TSWIM_Tired2", "UI_TSWIM_Tired3", "UI_TSWIM_Tired4" }   -- cles de traduction (Translate/xx/UI.json)

-- NOYADE : pour le joueur, Kill() cree le cadavre sur-le-champ (IsoGameCharacter.die -> becomeCorpse), aucun etat
-- d'animation de mort ne joue. On joue donc la noyade en EMOTE (emote/tswim_noyade, 4 s, mouvement bloque) puis on tue :
-- le cadavre garde la planche (ragdollFall = copie des os au moment de la mort).
local DROWN_MS = 4200   -- la planche est atteinte a 3,6 s et tenue jusqu a 5 s : on tue pendant la planche
function TS.startDrowning(p)
    local st = TS.stateOf(p)
    if not st or st.drowning then return end
    st.drowning = now()
    p:setVariable(VAR, true)
    p:setBlockMovement(true)
    local emitter = p:getEmitter()
    if emitter and emitter:isPlaying("TSWIM_Swim") then emitter:stopSoundByName("TSWIM_Swim") end
    local sq = p:getSquare()
    if sq then sq:startWaterSplash(true, 0, 0) end
    p:Say("...")
    p:playEmote("tswim_noyade")
    if TS_LOG then print("TrueSwimming: noyade commencee") end
    TS.stopPlanche(p)
end

-- appele a chaque image ou le joueur se deplace
function TS.onPlayerMove(p)
    if not TS.isSwimming(p) or not sbOn("Enabled", true) then return end
    local stx = TS.stateOf(p)
    if stx and stx.drowning then return end   -- en train de se noyer : plus de fatigue ni de degats, l'emote fait le reste
    -- l'ENDURANCE : en solo elle se retire ici, une image de deplacement = un appel. En multi c'est le SERVEUR qui la
    -- tient (IsoPlayer.updateEndurance sort tout de suite si GameClient.client ; le serveur la calcule sur sa copie et
    -- la renvoie par SyncPlayerStats / PlayerStats) : la retirer ici serait ecrase par sa valeur au paquet suivant —
    -- « la barre se recharge quand je nage », constate en coop le 22/09/2026. Le serveur applique donc TS.drain sur sa
    -- copie (TrueSwimmingServer.lua) ; le client garde l'XP, la perte d'objets et la noyade, qui lisent la valeur synchronisee.
    if not isClient() then TS.drain(p, 1) end
    local stats = p:getStats()
    -- (Aquatsar divisait le cout par 10 en visee ; ici la visee immobile = surplace sans deplacement, donc pas
    --  d'appel (isJustMoved faux) et la recuperation vanilla joue ; en visee + deplacement, plein tarif : pas de nage a
    --  prix casse en marchant de cote)
    p:getXp():AddXP(Perks.Fitness, 0.05)
    local endurance = stats:get(CharacterStat.ENDURANCE)
    -- COMPETENCE NATATION (perk custom "Swimming", declaree dans 42/media/perks.txt, chargee par CustomPerks du moteur) :
    -- meme recette que la course vanilla (server/XpSystem/XpUpdate.lua, onPlayerMove) : a chaque image de deplacement, une
    -- chance sur 700 (ajustee a la vitesse du jeu) de gagner 1 XP, tant que l'endurance est au-dessus du seuil d'alerte.
    -- Le niveau reduit le cout d'endurance dans TS.drain (partage client/serveur).
    -- pcall : si le multiplicateur global d'XP est coupe, le moteur cherche l'option sandbox "MultiplierConfig.Swimming"
    -- (declaree dans sandbox-options.txt) ; une erreur Java ici ne doit jamais interrompre le reste du tick.
    if Perks.Swimming and endurance > stats:getEnduranceWarning()
        and ZombRand(700 * GameTime.getInstance():getInvMultiplier()) == 0 then
        local okXp = pcall(function() p:getXp():AddXP(Perks.Swimming, 1) end)
        if not okXp and TS_LOG then print("TrueSwimming: AddXP Natation refuse par le moteur (option MultiplierConfig.Swimming ?)") end
    end
    local inv = p:getInventory()
    local weight = inv:getCapacityWeight()
    local maxWeight = p:getMaxWeight() * 0.9
    if sbOn("ItemLoss", true) and endurance < 0.3 then
        if weight > 1.5 * maxWeight and ZombRand(100) < 20 then TS.dropItems(p)
        elseif weight > maxWeight and ZombRand(100) < 5 then TS.dropItems(p) end
    end
    local drowning = sbv("Drowning", 1)
    if endurance < 0.05 then
        if drowning == 1 then
            -- blessures Aquatsar ; quand la vie est presque partie, la noyade prend le relais (sinon le moteur tue sans anim)
            if p:getBodyDamage():getOverallBodyHealth() <= 12 then TS.startDrowning(p); return end
            if ZombRand(100) < 5 then
                local part = p:getBodyDamage():getBodyPart(damagable[ZombRand(#damagable) + 1])
                if part then part:AddDamage(3) end
                saySometimes(p, getText("UI_TSWIM_Drowning"), 400)
            end
        end
    elseif endurance < 0.5 then
        saySometimes(p, getText(enduranceWords[ZombRand(#enduranceWords) + 1]), 10)
    end
    if drowning == 2 and endurance <= 0 then TS.startDrowning(p) end
end

-------------------------------------------------------------------------------
-- l'etat de nage (chaque tick)
-------------------------------------------------------------------------------
local state = {}   -- par joueur : { swimming = bool, ticks = n, drowning = ms ou nil }
function TS.stateOf(p)
    if not p then return nil end
    local i = p:getPlayerNum()
    if not state[i] then state[i] = { swimming = false, ticks = 0 } end
    return state[i]
end

-- mouille comme la pluie le fait : corps + stat WETNESS + vetements (TS.wetAll, fichier shared ; en multi le serveur
-- mouille aussi sa copie, sinon ses vetements secs ecrasent les notres)
local function wetClothes(p) TS.wetAll(p) end

-- l'eau lave (demande Workshop du 17/09/2026 ; regle fixee par Romain le 21/09 : « des qu'il rentre dans l'eau, au
-- bout de trois secondes il n'a plus de sang sur lui ni sur les habits qu'il porte »). Mecanique vanilla reprise de
-- ISWashYourself / ISWashClothing (media/lua/shared/TimedActions) : sang et saleté par partie du corps (HumanVisual /
-- ItemVisual, BloodBodyPartType, 0..1 ; parties couvertes d'un vetement via BloodClothingType.getCoveredParts), sang et
-- saleté globaux d'un vetement (Clothing.setBloodLevel / setDirtiness, 0..100). Sans savon ni lavabo : la riviere lave
-- tout d'un coup, une fois par baignade, WASH_TICKS apres l'entree dans l'eau.
local WASH_TICKS = 180   -- ~3 s a 60 images/s

local function washItem(item)
    local covered = BloodClothingType.getCoveredParts(item:getBloodClothingType())
    if covered then
        for j = 0, covered:size() - 1 do
            local part = covered:get(j)
            item:setBlood(part, 0)
            item:setDirt(part, 0)
        end
    end
    if instanceof(item, "Clothing") then
        item:setBloodLevel(0)
        item:setDirtiness(0)
    end
end

function TS.washInWater(p)
    local visual = p:getHumanVisual()
    if visual then
        for i = 1, BloodBodyPartType.MAX:index() do
            local part = BloodBodyPartType.FromIndex(i - 1)
            visual:setBlood(part, 0)
            visual:setDirt(part, 0)
        end
    end
    local worn = p:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item and (instanceof(item, "Clothing") or instanceof(item, "InventoryContainer")) then washItem(item) end
        end
    end
    p:resetModel()   -- comme ISWashClothing:perform (vetements) ; ISWashYourself utilise resetModelNextFrame (corps)
    p:resetModelNextFrame()
    triggerEvent("OnClothingUpdated", p)
    if TS_LOG then print("TrueSwimming: lave par l'eau") end
end

local function enterWater(p, st)
    st.swimming = true
    st.ticks = 0
    p:setVariable(VAR, true)
    p:setAuthorizedHandToHandAction(false)   -- coupe le bouton d'attaque a la source (lu dans updateInputState)
    local sq = p:getSquare()
    if sq then sq:startWaterSplash(true, 0, 0) end
    local emitter = p:getEmitter()
    if emitter then playSound(emitter, "TSWIM_Enter") end
    wetClothes(p)
end

local function leaveWater(p, st)
    st.swimming = false
    p:setVariable(VAR, false)
    p:setAuthorizedHandToHandAction(true)
    if st.lastSq and TS.isWater(st.lastSq) then st.lastSq:startWaterSplash(true, 0, 0) end   -- grande gerbe en sortant
    st.lastKey = nil; st.lastSq = nil
    local emitter = p:getEmitter()
    if emitter then
        if emitter:isPlaying("TSWIM_Swim") then emitter:stopSoundByName("TSWIM_Swim") end
        if not p:isDead() then playSound(emitter, "TSWIM_Leave") end
    end
    local sq = p:getSquare()
    if sq then sq:startWaterSplash(false, 0, 0) end
end

-------------------------------------------------------------------------------
-- franchir une barriere / rambarde VERS L'EAU avec la touche d'action (demande de Romain, 22/09/2026). Le saut automatique du
-- moteur (IsoPlayer.hopFence l.56) refuse une case d'arrivee qui porte le drapeau water, que notre ponton ne retire pas
-- (seul solidtrans l'est). L'autre voie, la touche d'action, ne regarde pas l'eau : addContextualAction(ClimbOverFence)
-- -> ClimbOverFenceState, qui traite la case d'arrivee comme un sol si elle est solidfloor (les tuiles d'eau le sont).
-- On declenche donc nous-memes l'ETAT d'escalade (setParams + EventClimbFence, le coeur de climbOverFence) quand le joueur
-- appuie sur la touche d'action face a une barriere franchissable dont la case d'en face est de l'eau : il retombe dans l'eau, le tick voit
-- l'eau et la nage demarre. La case d'en face est deja ouverte par le ponton (3x3 autour du joueur, des la rive).
-------------------------------------------------------------------------------
local HOP_CD = 45   -- images entre deux declenchements (le franchissement dure plus d'une seconde)
-- Declenche par la TOUCHE D'ACTION vanilla (Romain 22/09 : « que si le joueur appuie sur la touche grimper/sauter »),
-- via l'evenement Lua OnContextKey : le moteur l'emet quand la touche est utilisee et qu'AUCUNE action contextuelle
-- n'a ete retenue (IsoPlayer.doContext, l.4542) — precisement notre cas, puisque vanilla refuse l'escalade vers l'eau.
local function vaultIntoWater(p, st, ms)
    if st.hopCd and st.hopCd > 0 then return end
    if p:isDead() or p:isAiming() or p:getVehicle() or TS.isSwimming(p) then return end
    local name = p:getAnimationStateName()
    if name and string.find(name, "climb", 1, true) then return end
    local sq = p:getSquare(); if not sq then return end
    local dir = p:getDir()   -- la direction ou le joueur REGARDE (il peut etre a l'arret devant la rambarde)
    local fence, far
    if dir == IsoDirections.N and sq:has(IsoFlagType.HoppableN) then
        fence = sq:getHoppable(true);  far = getCell():getGridSquare(sq:getX(), sq:getY() - 1, sq:getZ())
    elseif dir == IsoDirections.W and sq:has(IsoFlagType.HoppableW) then
        fence = sq:getHoppable(false); far = getCell():getGridSquare(sq:getX() - 1, sq:getY(), sq:getZ())
    elseif dir == IsoDirections.S then
        local s2 = getCell():getGridSquare(sq:getX(), sq:getY() + 1, sq:getZ())
        if s2 and s2:has(IsoFlagType.HoppableN) then fence = s2:getHoppable(true); far = s2 end
    elseif dir == IsoDirections.E then
        local s2 = getCell():getGridSquare(sq:getX() + 1, sq:getY(), sq:getZ())
        if s2 and s2:has(IsoFlagType.HoppableW) then fence = s2:getHoppable(false); far = s2 end
    end
    if not fence or not far or not TS.isWater(far) then return end
    if far:isSolidTrans() then return end            -- le ponton n'est pas (encore) pose : on ne saute pas dans un mur
    -- (pas de isSafeToClimbOver : il repond FAUX des que la case d'en face porte le drapeau water, l.4285 ; le moteur
    --  lui-meme passe outre quand la touche d'action est tenue 0,5 s, l.4732 : ici c'est le joueur qui pousse vers l'eau)
    st.hopCd = HOP_CD
    if TS_LOG then print("TrueSwimming: franchissement vers l'eau, direction " .. tostring(dir)) end
    -- TOUTES les voies vanilla refusent une arrivee dans l'eau : hopFence (IsoPlayer l.56), et climbOverFence via
    -- IsoWindow.canClimbThroughHelper (has(water) -> false). On fait donc ce que climbOverFence fait APRES ses tests
    -- (IsoGameCharacter l.7773) : parametrer l'etat d'escalade et lui envoyer l'evenement. ClimbOverFenceState est expose
    -- a Lua ; l'etat lui-meme ne teste pas l'eau et traite l'arrivee comme un sol (solidfloor) grace au ponton.
    if not sq:isPlayerAbleToHopWallTo(dir, far) then return end   -- murs non franchissables (etage, escalier) : regle vanilla
    ClimbOverFenceState.instance():setParams(p, dir)
    p:reportEvent("EventClimbFence")
end

-------------------------------------------------------------------------------
-- FAIRE LA PLANCHE (Romain, 22/09/2026) : clic droit dans l'eau -> le nageur flotte sur le dos et se repose. Remplace le
-- « se reposer » vanilla (qui assoit le personnage) tant qu'on est dans l'eau. Repos = le drapeau isResting du moteur :
-- en solo IsoPlayer.updateEndurance prend alors la voie « assis » (updateEnduranceWhileSitting, sittingEnduranceMultiplier) ;
-- en multi c'est le serveur qui tient l'endurance : il lit la variable d'animation repliquee tswimPlanche sur sa copie
-- et pose isResting lui-meme (TrueSwimmingServer.lua). Tout mouvement ou sortie de l'eau arrete la planche (la visee tourne le nageur, comme assis).
-------------------------------------------------------------------------------
function TS.startPlanche(p)
    local st = TS.stateOf(p)
    if not st or not st.swimming or st.drowning or st.planche then return end
    st.planche = true
    p:setVariable("tswimPlanche", true)
    p:setIsResting(true)
    local emitter = p:getEmitter()
    if emitter and emitter:isPlaying("TSWIM_Swim") then emitter:stopSoundByName("TSWIM_Swim") end
end
function TS.stopPlanche(p, st)
    st = st or TS.stateOf(p)
    if not st or not st.planche then return end
    st.planche = false
    p:setVariable("tswimPlanche", false)
    p:setIsResting(false)
end

-------------------------------------------------------------------------------
-- 🦶 PIEDS NUS DANS L'EAU (05/10/2026, retours raptor x2 sur le Workshop : « blessures aux pieds en nageant, dans les rivieres ET
-- dans les piscines »). Lu dans le moteur 42.21, IsoPlayer.updateFootInjuries : sans chaussures (ou chaussures a 0), chaque image
-- de DEPLACEMENT compte comme une marche pieds nus : sol qui n'est pas « blends_natural_01 » hors batiment (le fond d'une piscine)
-- = 1, sol naturel en zone « Forest » (une riviere en foret) = 2 ; le compteur monte et finit par donner une griffure (+1 a +3 de
-- scratchTime, puis saignement 3-10 au-dela de 20) ou une coupure (+1 a +3 de cutTime) a un pied. Le moteur ne distingue pas la
-- nage de la marche. Le compteur est prive : on ne peut ni le lire ni le remettre a zero. On fait donc l'inverse : a chaque image
-- de nage on releve l'etat des deux pieds et on DEFAIT une blessure qui vient d'apparaitre avec exactement cette signature, sauf
-- si le joueur vient d'etre frappe (getHitReaction non vide : un zombie dans l'eau). Patauger (True Water) reste expose : les
-- pieds nus sur le gravier d'une riviere, c'est le jeu. Reglage console : TrueSwimming.PIEDS_NUS = false pour couper.
-------------------------------------------------------------------------------
TS.PIEDS_NUS = true
local PIEDS = { "Foot_L", "Foot_R" }
local function etatPied(part)
    return { scr = part:scratched(), scrT = part:getScratchTime(), cut = part:isCut(), cutT = part:getCutTime(), bleedT = part:getBleedingTime() }
end
local function protegerPieds(p, st)
    if not TS.PIEDS_NUS then st.pieds = nil; return end
    local ok, err = pcall(function()
        local bd = p:getBodyDamage()
        if not st.pieds then
            st.pieds = {}
            for k, nom in ipairs(PIEDS) do st.pieds[k] = etatPied(bd:getBodyPart(BodyPartType[nom])) end
            return
        end
        local frappe = p:getHitReaction()
        for k, nom in ipairs(PIEDS) do
            local part = bd:getBodyPart(BodyPartType[nom])
            local e = st.pieds[k]
            if not (frappe ~= nil and frappe ~= "") then
                local dScr, dCut = part:getScratchTime() - e.scrT, part:getCutTime() - e.cutT
                local neuf = ((not e.scr) and part:scratched() and part:getScratchTime() <= 3.05)
                          or (e.scr and dScr > 0 and dScr <= 3.05)
                          or ((not e.cut) and part:isCut() and part:getCutTime() <= 3.05)
                          or (e.cut and dCut > 0 and dCut <= 3.05)
                if neuf then
                    if not e.scr then part:setScratched(false, true) end
                    part:setScratchTime(e.scrT)
                    if not e.cut then part:setCut(false, true) end
                    part:setCutTime(e.cutT)
                    if e.bleedT == 0 and part:getBleedingTime() > 0 and part:getBleedingTime() <= 10.05 then
                        part:setBleedingTime(0); part:setBleeding(false)
                    end
                    -- TS 1.9 : le moteur a joue le grognement de douleur dans la meme image que la blessure
                    -- (IsoPlayer.updateFootInjuries -> possiblyPlayVoiceSound "PainFromScratch" / "PainFromGlassCut") ;
                    -- on le coupe aussitot (stopPlayerVoiceSound est public). Retour raptor 08/10.
                    p:stopPlayerVoiceSound("PainFromScratch")
                    p:stopPlayerVoiceSound("PainFromGlassCut")
                    if TS_LOG then print("TrueSwimming: blessure de pied nu dans l'eau annulee (" .. nom .. ")") end
                end
            end
            st.pieds[k] = etatPied(part)
        end
    end)
    if not ok and TS_LOG then print("TrueSwimming: protegerPieds : " .. tostring(err)) end
end

local function updatePlayer(i)
    local p = getSpecificPlayer(i)
    if not p then return end
    local stx = state[i]
    if stx and stx.drowning and not p:isDead() then
        if now() - stx.drowning >= DROWN_MS then
            if TS_LOG then print("TrueSwimming: noyade terminee -> mort") end
            -- le cadavre est dessine par DeadBodyAtlas avec l'AnimSet zombie/onground (pas de variables du mort), SAUF si
            -- ragdollFall est vrai : IsoDeadBody copie alors les transformations d'os du moment de la mort
            -- (canUseCurrentPoseForCorpse) et l'atlas les rejoue telles quelles -> la planche de fin d'emote devient la
            -- pose du cadavre, bassin cale au sol (= a la surface).
            -- (la photo des os via ragdollFall n'a pas tenu en jeu : 3 tests, cadavre sur le dos). Chemin qui ne depend
            -- pas des os : le cadavre d'un mort PAR CHUTE est rendu avec l'AnimSet player/deadbody et les variables
            -- KilledByFall / FallOnFront (FBORenderCorpses l.150-151, drapeaux sauvegardes avec le corps -> survit au
            -- rechargement). On marque donc le noye "mort par chute, face contre terre" et le noeud deadbody/tswim_cadavre
            -- (KilledByFall + FallOnFront, priorite 10) lui donne la planche.
            p:setRagdollFall(false)
            p:setFallOnFront(true)
            p:setKilledByFall(true)
            p:Kill(p)
        end
        return   -- rien d'autre pendant la noyade (la variable tswim reste vraie, les cases restent ouvertes)
    end
    if p:isDead() then return end   -- mort dans l'eau : on ne touche plus a rien, la variable tswim reste vraie pour
                                    -- la noyade en cours (emote) ; la pose du cadavre vient du ragdollFall (voir la fin de la noyade)
    local st = state[i]
    if not st then st = { swimming = false, ticks = 0 }; state[i] = st end
    local enabled = sbOn("Enabled", true)
    local swimming = enabled and TS.isSwimming(p)
    if swimming and not st.swimming then enterWater(p, st) end
    if not swimming and st.swimming then TS.stopPlanche(p, st); leaveWater(p, st); st.sortieNage = true; st.enfonce = false; st.pieds = nil end
    -- (la visee ne l'arrete PAS : comme assis par terre, le clic droit tourne le personnage vers la souris en restant
    --  sur le dos — noeuds aim / turningAim180 tswim_planche ; seul un deplacement le remet en surplace)
    if st.planche and (p:isPlayerMoving() or not swimming) then TS.stopPlanche(p, st) end
    if st.hopCd and st.hopCd > 0 then st.hopCd = st.hopCd - 1 end   -- delai entre deux franchissements vers l'eau
    if swimming then
        st.ticks = st.ticks + 1
        protegerPieds(p, st)
        -- la fatigue de la brasse, a chaque image ou le joueur a bouge. Meme condition que l'evenement OnPlayerMove du
        -- solo (IsoPlayer.update : isJustMoved && !isNpc), mais cet evenement n'est declenche QUE hors reseau
        -- (moteur 42.20.4, IsoPlayer l.2143 : !GameClient.client && !GameServer.server) : en multi il ne part jamais et
        -- l'endurance ne descendait pas (constate en coop le 22/09/2026). L'endurance est a l'autorite du client
        -- (aucune stat ENDURANCE dans les paquets reseau), donc la retirer ici vaut en solo comme en multi.
        if p:isJustMoved() then TS.onPlayerMove(p) end
        -- course et sprint permis : brasse plus rapide (noeuds run x1,4 / sprint x2) mais plus couteuse (x1,5 / x2,5)
        -- la visee reste possible (pour le joueur local, la machine d'etats tourne juste apres la lecture de la souris :
        -- un setIsAiming(false) depuis OnTick arrive toujours trop tard) : les etats aim / strafe / aim-strafe ont leurs
        -- propres noeuds de nage (surplace a l'arret, brasse en mouvement). L'ATTAQUE, elle, est coupee a la source :
        -- le bouton est lu derriere isAuthorizedHandToHandAction (updateInputState, DoAttack)
        if p:isAuthorizedHandToHandAction() then p:setAuthorizedHandToHandAction(false) end   -- une action chronometree finie le remet a true
        if p:getVariableBoolean(VAR) ~= true then p:setVariable(VAR, true) end
        -- sillage : le moteur ne sait dessiner qu'UNE eclaboussure par case, au centre de la case (renderFishSplash,
        -- 16 images ~1 s pour la petite, 32 pour la grande ; textures media/textures/waterSplashes). On en pose donc une
        -- petite sur chaque case que le nageur quitte (la trainee derriere lui) et une sur sa case tant qu'il avance.
        local sq = p:getSquare()
        if sq then
            local key = sq:getX() .. "," .. sq:getY()
            if st.lastKey ~= key then
                if st.lastSq and TS.isWater(st.lastSq) then st.lastSq:startWaterSplash(false, 0, 0) end
                st.lastKey = key
                st.lastSq = sq
            end
            if st.ticks % 40 == 0 and (p:isPlayerMoving() or p:isMoving()) then sq:startWaterSplash(false, 0, 0) end
        end
        -- trace de vitesse (TS_LOG) : distance parcourue par seconde, etat d'animation, sprint
        if TS_LOG and st.ticks % 60 == 0 then
            local x, y = p:getX(), p:getY()
            if st.px then
                local d = math.sqrt((x - st.px) ^ 2 + (y - st.py) ^ 2)
                print(string.format("TrueSwimming: vitesse %.2f case/s etat=%s sprint=%s course=%s",
                    d, tostring(p:getAnimationStateName()), tostring(p:isSprinting()), tostring(p:isRunning())))
            end
            st.px, st.py = x, y
        end
        -- son de nage (TSWIM_Swim, 17 s, recette Aquatsar : relance quand il s'est tu, tant que le nageur avance)
        local emitter = p:getEmitter()
        local moving = p:isPlayerMoving() or p:isMoving()   -- isPlayerMoving = les touches ; isMoving = l'etat (parfois faux en nage)
        if emitter then
            if moving then
                if not emitter:isPlaying("TSWIM_Swim") then
                    local handle = playSound(emitter, "TSWIM_Swim")
                    st.swimHandle = handle
                    if TS_LOG then print("TrueSwimming: son de nage lance, poignee=" .. tostring(handle)) end
                elseif st.swimHandle and st.ticks % 60 == 0 then
                    emitter:setVolume(st.swimHandle, soundVolume())   -- le son dure 17 s : suit les curseurs changes en cours de nage
                end
            elseif emitter:isPlaying("TSWIM_Swim") then
                emitter:stopSoundByName("TSWIM_Swim")
            end
        end
        if TS_LOG and st.ticks % 60 == 30 then
            print("TrueSwimming: diag son emetteur=" .. tostring(emitter ~= nil) .. " isPlayerMoving=" .. tostring(p:isPlayerMoving())
                .. " isMoving=" .. tostring(p:isMoving()) .. " joue=" .. tostring(emitter and emitter:isPlaying("TSWIM_Swim")))
        end
        if st.ticks % 60 == 0 then wetClothes(p) end   -- chaque seconde : en multi le serveur renvoie ses propres valeurs
        if st.ticks == WASH_TICKS and sbOn("Washing", true) then TS.washInWater(p) end   -- l'eau lave, 3 s apres l'entree (verifie en jeu le 21/09)
    end
    -- PATAUGEAGE (eau peu profonde, marche 6) : la marche dans l'eau remplace la nage sur les cases de classe 1 et 2 ;
    -- animations Bob_Eau_Cheville* (vanilla descendue) / Bob_Eau_Taille* (rig), noeuds hweau_* (variable STRING hweau)
    local palier = enabled and TS.isWading(p) or nil
    -- la case de BERGE (sol naturel au bord de l'eau, moitie sable moitie eau a l'ecran : pas « eau » pour le moteur) compte
    -- aussi : c'est la que Romain pose le pied en premier (capture 06/10 17h16 : debout, pieds secs, sur la berge) ;
    -- avec l'agent elle recevait l'enfoncement continu de berge (0,05), ici elle recoit directement « cheville »
    if not palier and enabled and not swimming and p:getZ() == 0 and not p:getVehicle() then
        local sqb = p:getSquare()
        if sqb and TS.classeDe and TS.berge(sqb:getX(), sqb:getY()) then palier = 1 end
    end
    -- TS 1.8 (True Water 2.0, plus d'agent) : la hauteur est CUITE dans les animations -> paliers par l'enfoncement continu :
    -- e1 (vanilla descendue 0,08) des la premiere case d'eau, e2 (0,16) ensuite, puis la pose « sous la taille » (rig).
    -- Seuils reglables a la console (TrueSwimming.SEUIL_E2 / SEUIL_TAILLE), petite hysteresis pour ne pas clignoter.
    local nomPalier = nil
    if palier then
        local enf = TS.enfoncementContinu(p:getX(), p:getY())
        -- des la PREMIERE case d'eau : « cheville » (Bob_Eau_Cheville, vanilla descendue de 0,11 = le reglage des egouts de True
        -- Sewers, Romain 06/10 : « il faut qu'il ait l'eau aux chevilles au debut comme pour les egouts ») ; puis e2 (0,16), puis taille
        -- deux paliers (06/10, Romain : « l'eau aux chevilles des le depart comme pour les egouts ») : cheville = vanilla descendue
        -- de 0,16 (= SEW.ENF_CANAL des egouts) des la premiere case, puis la pose « sous la taille » (rig) a partir de SEUIL_TAILLE
        local sT = TS.SEUIL_TAILLE + ((st.palier == "cheville") and 0.012 or ((st.palier == "taille") and -0.012 or 0))
        nomPalier = (enf < sT) and "cheville" or "taille"
    end
    if nomPalier ~= st.palier then
        st.palier = nomPalier
        if nomPalier then p:setVariable("hweau", nomPalier) else p:clearVariable("hweau") end
        local sqp = p:getSquare()
        if sqp and TS.isWater(sqp) then sqp:startWaterSplash(nomPalier == nil, 0, 0) end
        if nomPalier == "taille" then wetClothes(p) end
    end
    -- GESTES VANILLA dans l'eau (toux, eternuement, frisson, essuyer le front... : couche « ext », IsoPlayer.onIdlePerformFidgets /
    -- IsoGameCharacter.DoSneezeText posent la variable Ext) : leur animation porte la racine a hauteur normale -> le corps
    -- remontait sur l'eau le temps du geste (Romain 06/10 : « quand je tousse en nageant le perso se met sur l'eau »).
    -- Sans l'agent on ne peut plus l'enfoncer : on coupe le geste des qu'il apparait (le son de la toux reste).
    if (swimming or nomPalier) and (p:getVariableString("Ext") ~= "" or p:getVariableBoolean("ExtPlaying")) then
        p:clearVariable("Ext")
        p:setVariable("ExtPlaying", false)
    end
    -- SONDE (console -debug : TrueSwimming.SONDE = true) : etat et noeud d'animation courants toutes les demi-secondes
    if TS.SONDE and (not TS._sondeT or getTimestampMs() - TS._sondeT > 500) then
        TS._sondeT = getTimestampMs()
        print(string.format("TSONDE etat=%s anim=%s hweau=%s Weapon=%s aim=%s isAiming=%s | %s",
            tostring(p:getCurrentStateName()), tostring(p:getAnimationStateName()), tostring(p:getVariableString("hweau")),
            tostring(p:getVariableString("Weapon")), tostring(p:getVariableBoolean("aim")), tostring(p:isAiming()), tostring(p:getAnimationDebug())))
    end
    if nomPalier then
        st.wadeTicks = (st.wadeTicks or 0) + 1
        -- l'enfoncement du corps ENTIER (greffe du moteur d'eau), quelle que soit l'animation en cours (bousculade, attaque,
        -- visee comprises — Romain 23/09 : « en mode combat en pataugeant je ressors de l'eau ») : les animations de marche
        -- dans l'eau sont a hauteur normale, c'est cette variable qui les descend (cheville 0,11 / sous la taille 0,46)
        -- (l'enfoncement lui-meme est pose plus bas, en continu, des la derniere case de terre)
        local sqw = p:getSquare()
        if sqw and TS.isWater(sqw) and st.wadeTicks % 30 == 0 and (p:isPlayerMoving() or p:isMoving()) then sqw:startWaterSplash(false, 0, 0) end
        if nomPalier == "taille" and st.wadeTicks % 120 == 0 then wetClothes(p) end
    end
    -- ENFONCEMENT CONTINU hors nage (terre pres de l'eau, chevilles, taille) : interpole sous les pieds, jamais de saut ;
    -- en nageant, c'est la flottaison qui tient la variable
    if enabled and not swimming and TS.classeDe and not p:getVehicle() and p:getZ() >= 0 and p:getZ() < 1 then
        local enf = TS.enfoncementContinu(p:getX(), p:getY())
        if enf > 0.004 then
            -- RACCORD nage -> pataugeage (Romain 23/09 : « le raccord se voit ») : la valeur courante est CONTINUE entre les deux
            -- proprietaires (ici hors nage, TrueSwimmingFlottaison en nage) : on repart de la derniere valeur posee par la
            -- flottaison (st.enfCur) et on converge vers la cible pendant que le moteur fond la brasse vers la marche
            -- (BlendTime 0,5 s des noeuds hweau_taille) ; jamais de saut de la variable, la pose et la hauteur se fondent ensemble
            if not st.enfonce then st.enfCur = st.enfCur or enf; st.enfTrans = 40 end
            st.sortieNage = false
            local taux = 0.08
            if st.enfTrans and st.enfTrans > 0 then st.enfTrans = st.enfTrans - 1; taux = 0.10 end
            st.enfCur = st.enfCur + (enf - st.enfCur) * taux
            if math.abs(p:getVariableFloat("tw_enfoncement", 0) - st.enfCur) > 0.003 then p:setVariable("tw_enfoncement", st.enfCur) end
            st.enfonce = true
        elseif st.enfonce then
            st.enfonce = false
            st.enfCur = 0.0   -- retour sur la terre ferme : la prochaine entree repart de zero
            p:clearVariable("tw_enfoncement")
        end
    end
    -- cases franchissables : en nageant, et depuis la rive (on entre dans l'eau en marchant)
    local active = enabled and not p:isDead() and not p:getVehicle()
    TS.updateClipFor(clipKey(i), active and p:getSquare() or nil)
end

-------------------------------------------------------------------------------
-- les zombies ne nagent pas (mecanique dans TrueSwimmingShared.lua). En solo c'est ce fichier qui les tient a terre.
-- En multi AUSSI, pour les zombies que ce client SIMULE : le serveur confie chaque zombie au client le plus proche (celui
-- qu'il poursuit en priorite, NetworkZombieManager.updateAuth), c'est donc ici que tournent l'IA et le deplacement des
-- zombies qui collent au nageur — et ici seulement que le mur invisible peut tenir (le serveur ne fait que suivre nos
-- paquets de position). Constate en jeu le 22/09/2026 : sans ce mur cote client, un zombie tout proche suivait sur l'eau.
-- Les zombies simules ailleurs (isLocal() faux) sont laisses au serveur / a l'autre client.
-------------------------------------------------------------------------------
local swimmers = {}
local function keepZombiesAshore()
    local n = 0
    for pi = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(pi)
        if p and state[pi] and state[pi].swimming then n = n + 1; swimmers[n] = p end
    end
    for i = n + 1, #swimmers do swimmers[i] = nil end
    TS.keepZombiesAshore(swimmers, n, true)
end

local joueurs = {}
local function onTick()
    local n = 0
    for i = 0, getNumActivePlayers() - 1 do
        updatePlayer(i)
        local p = getSpecificPlayer(i)
        if p then n = n + 1; joueurs[n] = p end
    end
    for i = n + 1, #joueurs do joueurs[i] = nil end
    keepZombiesAshore()
    TS.zombiesPataugent(joueurs, n, true)
end

-------------------------------------------------------------------------------
-- barre d'endurance au-dessus de la tete (recette Swim Skill : ISPanel + ISCoordConversion.ToScreen)
-------------------------------------------------------------------------------
TS_EnduranceBar = ISPanel:derive("TS_EnduranceBar")
function TS_EnduranceBar:render()
    ISPanel.render(self)
    local v = self.value or 0
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    self:drawRect(0, 0, self.width, self.height, 0.7, 0, 0, 0)
    self:drawRect(1, 1, (self.width - 2) * v, self.height - 2, 0.9, self.r, self.g, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.8, 1, 1, 1)
end
function TS_EnduranceBar:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.value = 1; o.r = 0; o.g = 1
    return o
end
local bar = nil

local function updateBar()
    local p = getSpecificPlayer(0)
    local show = sbOn("ShowBar", true) and p and state[0] and state[0].swimming and p:getSquare() ~= nil
    if not show then
        if bar then bar:setVisible(false) end
        return
    end
    if not bar then
        bar = TS_EnduranceBar:new(0, 0, 52, 8)
        bar:initialise()
        bar:addToUIManager()
    end
    bar:setVisible(true)
    local x, y = ISCoordConversion.ToScreen(p:getX(), p:getY(), p:getZ(), 0)
    local zoom = getCore():getZoom(0)
    bar:setX(x / zoom - 26)
    bar:setY(y / zoom - 110 / zoom)
    local endu = p:getStats():get(CharacterStat.ENDURANCE)
    bar.value = endu
    if endu <= 0.3 then bar.r, bar.g = 1, 0 elseif endu <= 0.6 then bar.r, bar.g = 1, 1 else bar.r, bar.g = 0, 1 end
end

-------------------------------------------------------------------------------
-- menu contextuel epure dans l'eau (recette Aquatsar) : en B42 ces options sont ajoutees par le JAVA
-- (ISWorldObjectContextMenuLogic) puis l'evenement Lua OnFillWorldObjectContextMenu passe apres -> on les retire.
-- Doublure : les rappels eux-memes sont neutralises tant qu'on nage (menu manette, autre mod qui rajoute l'option...).
-------------------------------------------------------------------------------
local blockedOptions = { "ContextMenu_SitGround", "ContextMenu_SleepOnGround", "ContextMenu_SleepOnGroundPillow",
    "ContextMenu_Fishing", "ContextMenu_Build", "ContextMenu_Wash", "ContextMenu_Walk_to" }

local function pruneMenu(player, context, worldobjects, test)
    local p = getSpecificPlayer(player)
    if not p or not context or not (state[player] and state[player].swimming) then return end
    for i = 1, #blockedOptions do
        context:removeOptionByName(getText(blockedOptions[i]))
    end
end
Events.OnFillWorldObjectContextMenu.Add(pruneMenu)

local function plancheMenu(player, context, worldobjects, test)
    if test then return end
    local p = getSpecificPlayer(player)
    local st = state[player]
    if not p or not context or not st or not st.swimming or st.drowning or st.planche then return end
    context:addOption(getText("UI_TSWIM_Planche"), p, TS.startPlanche)
end
Events.OnFillWorldObjectContextMenu.Add(plancheMenu)

-- options de TEST (seulement tant que TS_LOG est vrai) : vider l'endurance / se noyer tout de suite
local function testMenu(player, context, worldobjects, test)
    if not TS_LOG or test then return end
    local p = getSpecificPlayer(player)
    if not p or not context or not (state[player] and state[player].swimming) then return end
    context:addOption("True Swimming (test) : vider l'endurance", p, function(pl) pl:getStats():set(CharacterStat.ENDURANCE, 0.03) end)
    context:addOption("True Swimming (test) : se noyer maintenant", p, function(pl) TS.startDrowning(pl) end)
end
Events.OnFillWorldObjectContextMenu.Add(testMenu)

local function isSwimmingIndex(player)
    local st = state[player]
    return st and st.swimming
end
if ISWorldObjectContextMenu and ISWorldObjectContextMenu.onSitOnGround then
    local vanillaSit = ISWorldObjectContextMenu.onSitOnGround
    ISWorldObjectContextMenu.onSitOnGround = function(player, ...)
        if isSwimmingIndex(player) then return end
        return vanillaSit(player, ...)
    end
end
if ISJoystickButtonRadialMenu and ISJoystickButtonRadialMenu.onToggleSit then
    local vanillaToggle = ISJoystickButtonRadialMenu.onToggleSit
    ISJoystickButtonRadialMenu.onToggleSit = function(playerObj, ...)
        if playerObj and playerObj.getPlayerNum and isSwimmingIndex(playerObj:getPlayerNum()) then return end
        return vanillaToggle(playerObj, ...)
    end
end

-------------------------------------------------------------------------------
-- securite : jamais de case d'eau laissee debloquee
-------------------------------------------------------------------------------
Events.OnTick.Add(onTick)
-- (plus d'Events.OnPlayerMove : evenement solo seulement, la fatigue est appelee depuis le tick, voir updatePlayer)
Events.OnPostUIDraw.Add(updateBar)
Events.OnContextKey.Add(function(p, ms)
    if not p or not sbOn("Enabled", true) then return end
    local st = TS.stateOf(p); if st then vaultIntoWater(p, st, ms) end
end)
Events.OnPlayerDeath.Add(function(p)
    restoreAll()
    -- noye : tswim reste vrai (anim de mort + pose du cadavre) ; mort ailleurs : on nettoie
    local stx = p and state[p:getPlayerNum()]
    if p and not (stx and (stx.swimming or stx.drowning)) then p:setVariable(VAR, false) end
    -- l'etat du mod est PAR EMPLACEMENT joueur : on l'efface, sinon un nouveau survivant heriterait de la noyade en cours
    -- (bug vu le 16/09 : nouveau personnage dans le meme monde, tue des son apparition)
    if p then state[p:getPlayerNum()] = nil end
end)
Events.OnCreatePlayer.Add(function(i) state[i] = nil end)
Events.OnSave.Add(restoreAll)
