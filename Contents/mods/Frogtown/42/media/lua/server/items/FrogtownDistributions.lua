local frogtownDistributionTable = {
    FrogtownFrogInfestation = {
        cardboardbox = {
            procedural = true,
            procList = {
                {name="FrogtownFrogs", min=1, max=5, weightChance=100},
                }
            },
        smallbox = {
            procedural = true,
            procList = {
                {name="FrogtownFrogs", min=1, max=5, weightChance=100},
                }
            },
        counter = {
            procedural = true,
            procList = {
                {name="FrogtownFrogs", min=1, max=5, weightChance=100},
                }
            },
        shelves = {
            procedural = true,
            procList = {
                {name="FrogtownFrogs", min=1, max=5, weightChance=100},
                }
            },
        locker = {
            procedural = true,
            procList = {
                {name="FrogtownFrogs", min=1, max=5, weightChance=100},
                }
            },
        metal_shelves = {
            procedural = true,
            procList = {
                {name="FrogtownFrogs", min=1, max=5, weightChance=100},
                }
            },
    }
}

table.insert(Distributions, 2, frogtownDistributionTable);
