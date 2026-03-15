require "StashDescriptions/StashUtil";
--[[

La siguiente información se encuentran en el archivo stashutil que se está llamando.

Estos son los parámetros para el addStamp:
	addStamp(symbol,text,mapX,mapY,r,g,b)

Estos son los parámetros del addStamp:
	addStamp(symbol,text,mapX,mapY,anchorX,anchorY,rotation,r,g,b)

los r,g,b normalmente son valores dentro de 0 y 255 pero
para éste caso deben estar dentro de 0 y 1, para lograrlo
dividamos el valor entre 255 pero sólo usemos hasta dos dígitos
del resultado. Ejemplo:
un valor r = 250 al dividir nos resulta 0.9803921568627451
o más pero se reduce a 0.98

los x,y,z son coordenadas dentro del mundo pero hasta el momento,
sólo el z tiene números negativos en los sótanos
y no sé si esté bien preparada esa parte por lo que sugiero
mejor usar sólo niveles positivos o la planta baja,
o sea 0

--
--Black: 0.129, 0.129, 0.129
--Red: 0.65, 0.054, 0.054
--Blue: 0.156, 0.188, 0.49
--Green: 0.06, 0.39, 0.17
]]--

-- guns
local stashMap1 = StashUtil.newStash("MockingbirdStashMap1", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true; -- Define si se encontrará el mapa anotado sólo en zombies
stashMap1.daysToSpawn = "1"; -- Días para que se aparezca
stashMap1.zombies = 5; -- Número de zombies que con mayor probabilidad aparecerán en el edificio
stashMap1.traps = "5"; -- Número de trampas probables
stashMap1.barricades = 50; -- Número de tablas para puertas y ventanas
stashMap1.buildingX = 10333; -- Eje X del edificio. casa Goku
stashMap1.buildingY = 13068; -- Eje Y del edificio. Goku
stashMap1.spawnTable = "GunCache2"; -- Tabla de armas, GunCache2 tipo pistola o ShotgunCache2 tipo escopetas o ToolsCache1 para herramientas o SurvivorCache1 para sobrevivientes
stashMap1:addContainer("GunBox", "floors_interior_tilesandwood_01_62", nil, "bedroom", nil, nil, nil); -- Tipo de contenedor, tilde, mochila, habitación, ejeX, ejeY, ejeZ. Si se usa tilde no se pone mochila
stashMap1:addStamp("Cross", nil, 10335, 13070, 0.06, 0.39, 0.17); -- Símbolo, texto, ejeX, ejeY, Rojo, Verde, Azul. Si se usa símbolo no se pone texto.
stashMap1:addStamp(nil, "Stash_WpMap1_Text1", 10255, 13032, 0.129, 0.129, 0.129); -- "Seguro que vivía aquí"
stashMap1:addStamp("OnePunchMan",nil,10403, 12958, 0.156, 0.188, 0.49); -- Saitama. los símbolos se encuentran en "media/ui/LootableMaps/"
stashMap1:addStamp(nil,"Stash_WpMap1_Text2", 10280, 12973, 0.129, 0.129, 0.129); -- "son demasiados, no dispares cerca de aquí por el amor de Dios" los textos se encuentran en "media\lua\shared\translate\en\Stash_EN.txt"
stashMap1:addStamp("Munsters", nil, 10425, 13010, 0.65, 0.054, 0.054); -- Exclamación, Munster Mansion
stashMap1:addStamp(nil, "Stash_WpMap2_Text3", 10217, 13024, 0.65, 0.054, 0.054); -- "la encontré caminando por aquí, no llevaba el arma" los textos se encuentran en "media\lua\shared\translate\es\Stash_ES.txt"

local stashMap1 = StashUtil.newStash("MockingbirdStashMap2", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10383; -- warehouse
stashMap1.buildingY = 12966;
stashMap1.zombies = 6;
stashMap1.barricades = 40;
stashMap1.spawnTable = "GunCache2";
stashMap1:addContainer("GunBox", "floors_interior_tilesandwood_01_62", nil, "bedroom", nil, nil, nil); -- "floors_interior_tilesandwood_01_62" es el piso de madera, escondido y necesita herramientas tipo desarmador o martillo o ambos.
stashMap1:addContainer("GunBox", "carpentry_01_16", nil, nil, nil, nil, nil); -- "carpentry_01_16" es una caja de madera
stashMap1:addStamp("Target", nil, 10385, 12967, 0.129, 0.129, 0.129); -- Objetivo, warehouse
stashMap1:addStamp("Munsters", nil, 10425, 13010, 0.65, 0.054, 0.054); -- Munster Mansion
stashMap1:addStamp(nil, "Stash_RiversideStashMap6_Text1", 10202, 13021, 0.129, 0.129, 0.129); -- "Eddie debe tener algunas armas escondidas aquí"
stashMap1:addStamp("Gasolinera", nil, 10460, 13060, 0.06, 0.39, 0.17); -- Gasolinera, almacenes
stashMap1:addStamp(nil, "Stash_RiversideStashMap9_Text2", 10250, 13015, 0.129, 0.129, 0.129); -- "gasolina"

-- shotgun
local stashMap1 = StashUtil.newStash("MockingbirdStashMap3", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10387; -- Casa abuelita
stashMap1.buildingY = 13113;
stashMap1.zombies = 14;
stashMap1.barricades = 75;
stashMap1.spawnTable = "MedicalCache1";
stashMap1:addContainer("MedicalBox", "floors_interior_tilesandwood_01_62", nil, "bedroom", nil, nil, nil);
stashMap1:addStamp("OnePunchMan", nil, 10360, 13070, 0.156, 0.188, 0.49); -- Saitama departamentos.
stashMap1:addStamp(nil, "Stash_MulMap10_Text1", 10255, 13080, 0.65, 0.054, 0.054); -- "casa de la muerte"
stashMap1:addStamp("Cross", nil, 10400, 13114, 0.06, 0.39, 0.17); -- Casa abuelita
stashMap1:addStamp("Munsters", nil, 10425, 13010, 0.65, 0.054, 0.054); -- Munster Mansion

local stashMap1 = StashUtil.newStash("MockingbirdStashMap4", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10212; -- Casa grande campo
stashMap1.buildingY = 12981;
stashMap1.zombies = 6;
stashMap1.barricades = 50;
stashMap1.spawnTable = "ShotgunCache2";
stashMap1:addContainer("ShotgunBox", nil, "Base.Bag_DuffelBag", nil, nil, nil, nil);
stashMap1:addContainer("ShotgunBox", "carpentry_01_16", nil, nil, nil, nil, nil);
stashMap1:addStamp("House", nil, 10213, 12982, 0.054, 0.65, 0.054); -- Casa grande campo
stashMap1:addStamp("Cross", nil, 10383, 13115, 0.06, 0.39, 0.17);
stashMap1:addStamp(nil, "Stash_MulMap4_Text2", 10290, 13110, 0.65, 0.054, 0.054); -- "médico"
stashMap1:addStamp("Cross", nil, 10383, 13095, 0.06, 0.39, 0.17); -- CJ house
stashMap1:addStamp(nil, "Stash_LVMap6_Text1", 10285, 13085, 0.65, 0.054, 0.054); -- "¡NO HAY LUGAR COMO EL HOGAR!"

-- tools
local stashMap1 = StashUtil.newStash("MockingbirdStashMap5", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10255; -- Casa Izquierda superior calle dos contando de arriba a abajo
stashMap1.buildingY = 13002;
stashMap1.zombies = 2;
stashMap1.barricades = 50;
stashMap1.spawnTable = "ToolsCache1";
stashMap1:addContainer("ToolsBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, nil);
stashMap1:addStamp("Circle", nil, 10257, 13002, 0.129, 0.129, 0.129); -- Casa Izquierda superior calle dos contando de arriba a abajo
stashMap1:addStamp(nil, "Stash_LVMap13_Text1", 10247, 12992, 0.65, 0.054, 0.054); -- "casas seguras"
stashMap1:addStamp("Munsters", nil, 10425, 13010, 0.65, 0.054, 0.054); -- Munster Mansion

local stashMap1 = StashUtil.newStash("MockingbirdStashMap6", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10383; -- warehouse
stashMap1.buildingY = 12966;
stashMap1.zombies = 6;
stashMap1.barricades = 50;
stashMap1.spawnTable = "ToolsCache1";
stashMap1:addContainer("ToolsBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, 1);
stashMap1:addContainer("ToolsBox", "carpentry_01_16", nil, nil, nil, nil, 1);
stashMap1:addStamp("Exclamation", nil, 10385, 12970, 0.129, 0.129, 0.129); -- Casa Izquierda inferior calle dos contando de arriba a abajo
stashMap1:addStamp(nil, "Stash_LVMap6_Text1", 10202, 13021, 0.65, 0.054, 0.054); -- "¡NO HAY LUGAR COMO EL HOGAR!"
stashMap1:addStamp("OnePunchMan", nil, 10360, 13070, 0.156, 0.188, 0.49); -- Saitama departamentos.

-- survivor houses
local stashMap1 = StashUtil.newStash("MockingbirdStashMap7", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10346; -- Cazafantasmas
stashMap1.buildingY = 13019;
stashMap1.zombies = 5;
stashMap1.barricades = 50;
stashMap1.spawnTable = "SurvivorCache1";
stashMap1:addContainer("GunBox", "floors_interior_tilesandwood_01_62", nil,"bedroom", nil, nil, 2);
stashMap1:addContainer("ShotgunBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, 3);
stashMap1:addStamp("Munsters", nil, 10425, 13010, 0.65, 0.054, 0.054); -- Munster Mansion
stashMap1:addStamp(nil, "Stash_WpMap11_Text3", 10202,13021, 0.129, 0.129, 0.129); -- "evitaré estar cerca de casa - no me busques aquí"
stashMap1:addStamp("Ghostbusters", nil, 10347, 13025, 0.65, 0.054, 0.054); -- cazafantasmas

local stashMap1 = StashUtil.newStash("MockingbirdStashMap8", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10419; -- Munster Mansion
stashMap1.buildingY = 13007;
stashMap1.zombies = 5;
stashMap1.barricades = 80;
stashMap1.spawnTable = "SurvivorCache1";
stashMap1:addContainer("ToolsBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, nil);
stashMap1:addContainer("ToolsBox", "carpentry_01_16", nil, nil, nil, nil, nil);
stashMap1:addContainer("GunBox", "carpentry_01_16", nil, nil, nil, nil, 1);
stashMap1:addContainer("ShotgunBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, 1);
stashMap1:addStamp("Munsters", nil, 10425, 13010, 0.65, 0.054, 0.054); -- Casa, Munster Mansion
stashMap1:addStamp("Cross", nil, 10397, 13132, 0.06, 0.39, 0.17); -- una X, Ant House
stashMap1:addStamp(nil, "Stash_RosewoodStashMap3_Text11", 10393, 13143, 100, 15, 0, 0.65, 0.054, 0.054); -- "La antigua casa de mamá. Te veré allí, besos"

local stashMap1 = StashUtil.newStash("MockingbirdStashMap9", "Map", "Base.MockingbirdMap", "Stash_AnnotedMap");
stashMap1.spawnOnlyOnZed = true;
stashMap1.daysToSpawn = "0";
stashMap1.buildingX = 10379; -- 6Pisos
stashMap1.buildingY = 13000;
stashMap1.zombies = 5;
stashMap1.barricades = 80;
stashMap1.spawnTable = "SurvivorCache1";
stashMap1:addContainer("ToolsBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, nil);
stashMap1:addContainer("ToolsBox", "floors_interior_tilesandwood_01_62", nil, nil, nil, nil, nil);
stashMap1:addContainer("GunBox", "floors_interior_tilesandwood_01_62", nil, nil, nil, nil, 3);
stashMap1:addContainer("ShotgunBox", nil, "Base.Bag_DuffelBagTINT", nil, nil, nil, 3);
stashMap1:addStamp("House", nil, 10380, 13002, 0.06, 0.39, 0.17); -- Casa, 6Pisos
stashMap1:addStamp("Ghostbusters", nil, 10347, 13025, 0.129, 0.129, 0.129); -- Ghostbusters
stashMap1:addStamp("Munsters", nil, 10420, 13007, 0.129, 0.129, 0.129, 0.129); -- Munsters Mansion
stashMap1:addStamp("Gasolinera", nil, 10455, 13011, 0.06, 0.39, 0.17); -- Gasolinera
stashMap1:addStamp("OnePunchMan", nil, 10359, 13066, 0.156, 0.188, 0.49); -- Saitama
stashMap1:addStamp("Cross", nil, 10397, 13132, 0.06, 0.39, 0.17); -- una X, Ant House
stashMap1:addStamp(nil, "Stash_RosewoodStashMap3_Text11", 10293, 13143, 0.129, 0.129, 0.129); -- "La antigua casa de mamá. Te veré allí, besos"
