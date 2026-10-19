-- True Swimming — FLOTTAISON (moteur d'eau, marche 4, 23/09/2026).
-- Une physique de flottaison en Lua : a chaque image de nage, on calcule une cible d'IMMERSION (en unites jeu, positif = le
-- corps plus BAS que la hauteur cuite dans l'animation) a partir du poids porte, de l'endurance, de la forme (traits,
-- Fitness), du mouvement (nage / arret / planche) et des vetements mouilles ; on la lisse, on y ajoute une respiration,
-- et on la pose dans la variable d'animation "tw_enfoncement". Sans l'agent Java (greffe 2 du moteur d'eau), la variable est
-- inerte : le mod reste exactement celui du Workshop. Avec l'agent, le modele 3D est dessine plus bas d'autant, en continu.
-- Chiffres de reference (etudes lues le 22/09) : immerge jusqu'au nombril, ~50 % du poids est porte par l'eau ; la graisse
-- flotte (Obese/Overweight = plus haut), le muscle coule (Athletic = un peu plus bas) ; un sac tire vers le fond.
require "TrueSwimmingShared"

TrueSwimming = TrueSwimming or {}
local TS = TrueSwimming
local VAR = "tw_enfoncement"

local IMMERSION_MAX = 0.40      -- au-dela, la tete passe sous l'eau : c'est la noyade (existante) qui prend le relais
local LISSAGE = 0.035           -- part de l'ecart rattrapee par image (~0,5 s pour se poser)

local etat = {}   -- par joueur : { courant = float, ticks = n }

local function enduranceDe(p)
    local ok, v = pcall(function() return p:getStats():get(CharacterStat.ENDURANCE) end)
    if ok and v then return v end
    local ok2, v2 = pcall(function() return p:getStats():getEndurance() end)
    if ok2 and v2 then return v2 end
    return 1.0
end

local function poidsVetements(p)
    local total = 0
    local ok = pcall(function()
        local worn = p:getWornItems()
        if not worn then return end
        for i = 0, worn:size() - 1 do
            local wi = worn:get(i)
            local item = wi and wi:getItem()
            if item then total = total + item:getActualWeight() end
        end
    end)
    if not ok then return 0 end
    return total
end

-- la cible d'immersion pour ce joueur, cette image
local function cible(p, st)
    local c = 0.0
    -- le poids porte tire vers le fond : rien jusqu'a 8 kg, puis 1,2 cm par kg (20 kg -> +0,14 ; 30 kg -> +0,26)
    local poids = p:getInventory():getCapacityWeight()
    if poids > 8 then c = c + (poids - 8) * 0.012 end
    -- les vetements mouilles alourdissent (une tenue complete ~5 kg -> +0,03)
    c = c + poidsVetements(p) * 0.006
    -- la fatigue : plus l'endurance baisse, moins on se tient hors de l'eau (epuise -> +0,28, la bouche au ras de l'eau)
    local e = enduranceDe(p)
    local fatigue = 1.0 - e
    c = c + fatigue * fatigue * 0.28
    -- la forme : la graisse flotte, le muscle coule
    if p:hasTrait(CharacterTrait.OBESE) then c = c - 0.05
    elseif p:hasTrait(CharacterTrait.OVERWEIGHT) then c = c - 0.02 end
    if p:hasTrait(CharacterTrait.ATHLETIC) then c = c + 0.02 end
    if p:hasTrait(CharacterTrait.UNFIT) then c = c + 0.02 end
    c = c - (p:getPerkLevel(Perks.Fitness) - 5) * 0.004   -- un bon nageur se tient un peu plus haut
    -- le mouvement : nager porte, s'arreter fait descendre un peu, la planche porte sans effort
    -- (retour Romain 23/09 : « au crawl on a l'impression qu'il est SUR l'eau, pareil pour la planche » -> une ligne de
    --  flottaison de repos propre a chaque nage : crawl +0,05 (les jambes sous l'eau), course +0,03, brasse +0,01, planche +0,04)
    if st and st.planche then
        c = c * 0.5 + 0.07
    elseif p:isPlayerMoving() or p:isMoving() then
        if p:isSprinting() then c = c + 0.085 elseif p:isRunning() then c = c + 0.055 else c = c + 0.03 end   -- crawl : +0,10/+0,07 -> remonte de 0,03 puis redescendu de 0,015 (Romain 23/09, apres la greffe 3) ; brasse 0,01 -> 0,03 (Romain 25/09 : « tres leger » plus bas)
    else
        c = c + 0.07   -- surplace : 0,05 -> 0,07 (Romain 25/09 : le perso statique depasse un peu trop de la ligne d'eau)
    end
    if c < -0.06 then c = -0.06 end
    if c > IMMERSION_MAX then c = IMMERSION_MAX end
    return c
end

local SYNCED = false
local function syncVar()
    if isClient() and not SYNCED and addVariableToSyncList then addVariableToSyncList(VAR); SYNCED = true end
end
syncVar()
Events.OnGameStart.Add(syncVar)

local function tick()
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then
            local st = TS.stateOf(p)
            local f = etat[i]
            if not f then f = { courant = 0.0, ticks = 0 }; etat[i] = f end
            local nage = st and st.swimming and not st.drowning
            if nage then
                -- RACCORD pataugeage -> brasse (Romain 23/09 : « le raccord se voit ») : la variable ne doit JAMAIS sauter au
                -- changement d'etat, sinon la pose de marche encore a 100 % au premier tick du fondu est dessinee d'un coup
                -- 0,45 plus haut (il ressort de l'eau avant de plonger). On repart donc de la valeur courante du pataugeage
                -- (st.enfCur, tenue par TrueSwimming.lua) et on converge vers la cible de flottaison pendant que le moteur
                -- fond la marche vers la brasse (BlendTime 0,5 s des noeuds tswim) : la hauteur et la pose se fondent ensemble
                if f.ticks == 0 then f.courant = (st and st.enfCur) or 0.0 end
                f.ticks = f.ticks + 1
                local c = cible(p, st)
                f.courant = f.courant + (c - f.courant) * (f.ticks < 40 and 0.10 or LISSAGE)
                if st then st.enfCur = f.courant end   -- la valeur courante partagee (continuite a la sortie de l'eau)
                -- respiration : le corps monte et descend doucement (1 cm, 4 s)
                local v = f.courant + math.sin(f.ticks / 60 * math.pi / 2) * 0.01
                if v < -0.15 then v = -0.15 end
                p:setVariable(VAR, v)
                if TS.LOG and f.ticks % 120 == 0 then   -- trace (diagnostic, TS_LOG)
                    print(string.format("TrueSwimming flottaison: cible=%.3f courant=%.3f poids=%.1f endurance=%.2f", c, f.courant, p:getInventory():getCapacityWeight(), enduranceDe(p)))
                end
            elseif f.courant ~= 0 or f.ticks ~= 0 then
                f.courant = 0.0; f.ticks = 0
                -- hors nage, TrueSwimming.lua tient la variable (enfoncement continu terre -> pataugeage) : on ne l'efface que si
                -- elle ne vaut plus rien (pas d'eau autour)
                if TrueSwimming.enfoncementContinu and TrueSwimming.enfoncementContinu(p:getX(), p:getY()) <= 0.004 then p:clearVariable(VAR) end
            end
        end
    end
end
Events.OnTick.Add(tick)
Events.OnCreatePlayer.Add(function(i) etat[i] = nil end)
