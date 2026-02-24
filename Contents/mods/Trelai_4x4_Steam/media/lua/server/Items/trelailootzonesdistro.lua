--for mod compat:
--ProceduralDistributions = distributionTable;
--table.insert(trelaiProceduralDistributions.list, distributionTable);
local trelaidistributionTable = {
--ProceduralDistributions.list = {
--roomdef
            vault = {
--containertype
            gold = {
            procedural = true,
--itemlist Proclist Defined in = ProceduralDistributions
            procList = {
                {name="vaultgoldstack", min=5, max=50},
                {name="vaultgoldstack", min=2, max=50,  forceForZones="trelaibank"},
				        {name="vaultgoldstack", min=1, max=50,  forceForZones="trelaibank"},
                {name="vaultgoldstack", min=1, max=10,  forceForZones="trelaibank"},
                {name="vaultgoldstack", min=3, max=10,  forceForZones="trelaibank"},
                }
            },
        },

            vault2 = {
            Crown = {
            procedural = true,
            procList = {
             {name="Crown", min=2, max=2, forceForZones="trelaibank"},
                }
            },
        },

                Bedroom = {
                BedroomSideTable = {
                procedural = true,
                procList = {
                {name="BedroomAcademy", min=5, max=10,},
                {name="BedroomAcademy", min=5, max=50, forceForZones="Academy"},
                {name="BedroomAcademy", min=5, max=50, forceForZones="Academy"},
                {name="BedroomAcademy", min=5, max=50, forceForZones="Academy"},
                }
            },
        },

        boysdorm = {
            crate = {
            procedural = true,
            procList = {
             {name="BedroomAcademy", min=5, max=50, forceForZones="Academy"},
             {name="BedroomAcademy", min=5, max=50, forceForZones="Academy"},
             {name="BedroomAcademy", min=5, max=50, forceForZones="Academy"},
                }
            },
        },
            PoliceClothes = {
            locker = {
            procedural = true,
            procList = {
            {name="PoliceClothes", min=1, max=50,},
            {name="PoliceClothes", min=1, max=50, forceForZones="TPolice"},
            {name="PoliceClothes", min=1, max=50, forceForZones="TPolice"},
                }
            },
        },
        FireClothes = {
          locker = {
          procedural = true,
          procList = {
          {name="FireClothes", min=1, max=50,},
          {name="FireClothes", min=1, max=50, forceForZones="TFire"},
          {name="FireClothes", min=1, max=50, forceForZones="TFire"},
              }
          },
      },
      StoryNote = {
          notebook = {
          procedural = true,
          procList = {
          {name="StoryNote", min=1, max=2,},
              }
          },
      },
      
      all = {
        bat = {
        procedural = true,
        procList = {
        {name="bat", min=1, max=2,},
            }
        },

        chest = {
        procedural = true,
        procList = {
        {name="treasurechest", min=1, max=2,},
            }
        },
      },
}

table.insert(Distributions, 2, trelaidistributionTable);
--table.insert(ProceduralDistributions.list, distributionTable);

--Trelai Story Notes Spawn on Zombies--
local StorytrelainotesDistributions = {
    all = {
      inventorymale = {
        items = {
          "Trelai.trelainotes_01", 0.05,
    
        }
      },
      inventoryfemale = {
        items = {
          "Trelai.trelainotes_01", 0.05,
  
        }
      },
    }
  }
  
  -- add loot table additions to the end of Distributions, so the game will take care of merging it
  table.insert(Distributions, StorytrelainotesDistributions)