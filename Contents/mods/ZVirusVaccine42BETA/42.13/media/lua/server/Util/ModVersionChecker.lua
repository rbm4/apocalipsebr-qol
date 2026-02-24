-- NOT NEEDE ANYMORE.
-- LEFT HERE FOR REFERENCE IN CASE OF FUTURE MIGRATION NEEDS.

local LAB_MOD_VERSION = 1

local function Lab_CheckModVersion()
    local md = ModData.getOrCreate("LabMod")
    
    if md.ModVersion == LAB_MOD_VERSION then
        if md.MigrationPending then
            print("[Zombie Virus Vaccine]: Clearing old migration pending.")
            md.MigrationPending = nil
            ModData.transmit("LabMod")
        end
        return
    end
    
    if not md.ModVersion then
        md.ModVersion = LAB_MOD_VERSION
        print("[Zombie Virus Vaccine]: New save - Mod version set to", LAB_MOD_VERSION)
        ModData.transmit("LabMod")
        return
    end
    
    print("[Zombie Virus Vaccine]: Mod version migration", md.ModVersion, ">", LAB_MOD_VERSION)
    md.ModVersion = LAB_MOD_VERSION
    md.MigrationPending = true
    if not md.CompensatedPlayers then
        md.CompensatedPlayers = {}
    end
    ModData.transmit("LabMod")
end

-- THE IDEA WAS TO COMPENSATE PLAYERS WHO LOST PROGRESS DUE TO MAJOR UPDATES.
-- THE MAIN CODE ABOVE MARKS THE SAVE WITH A VERSION AND A FLAG FOR PENDING MIGRATION. THEN, ONCE THE PLAYER LOGS IN, THE NEXT PIECE OF CODE (NOT PRESENT HERE) CHECKS IF THEY'RE AFFECTED AND COMPENSATE THEM IF NEEDED.
-- HOWEVER, THIS SYSTEM WAS DEEMED UNNECESSARY FOR NOW, AS THE APPROACH TO UPDATES WAS CHANGED TO BE MORE BACKWARD COMPATIBLE, AVOIDING THE NEED FOR SUCH COMPENSATIONS.