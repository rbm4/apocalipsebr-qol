require "Items/ProceduralDistributions"
require "XpSystem/XPSystem_SkillBook"

MissingSkillBooks = MissingSkillBooks or {}


function MissingSkillBooks.makeBookList(skillName)

    local books = {}

    for volume = 1, 5 do
        books[volume] =
            "MissingSkillBooks.Book" .. skillName .. volume
    end

    return books
end


function MissingSkillBooks.applySkillBookSettings(
    skillBookName,
    perk,
    optionPrefix
)

    local settings = SandboxVars.MissingSkillBooks

    SkillBook[skillBookName] =
        SkillBook[skillBookName] or {}

    SkillBook[skillBookName].perk = perk

    for volume = 1, 5 do

        local optionName =
            optionPrefix .. "XP" .. volume

        local multiplier =
            settings[optionName]

        SkillBook[skillBookName][
            "maxMultiplier" .. volume
        ] = multiplier
    end
end


local function addItem(
    distributionName,
    itemName,
    chance
)

    local distribution =
        ProceduralDistributions.list[distributionName]

    if distribution and distribution.items then
        table.insert(distribution.items, itemName)
        table.insert(distribution.items, chance)
    end
end


local function removeItem(
    distributionName,
    itemName
)

    local distribution =
        ProceduralDistributions.list[distributionName]

    if not distribution
    or not distribution.items then
        return
    end

    local items = distribution.items

    for i = #items - 1, 1, -2 do

        if items[i] == itemName then
            table.remove(items, i + 1)
            table.remove(items, i)
        end
    end
end


function MissingSkillBooks.applyBookLoot(
    books,
    distributions,
    enabled,
    spawnMultiplier
)

    for distributionName, _ in pairs(distributions) do

        for _, itemName in ipairs(books) do
            removeItem(
                distributionName,
                itemName
            )
        end
    end


    if not enabled then
        return
    end


    for distributionName, chances in pairs(distributions) do

        for volume, baseChance in ipairs(chances) do

            local finalChance =
                baseChance * spawnMultiplier

            addItem(
                distributionName,
                books[volume],
                finalChance
            )
        end
    end
end

function MissingSkillBooks.getStandardBookDistributions()

    return {
        BookstoreBooks = {
            10, 8, 6, 4, 2
        },

        LibraryBooks = {
            8, 6, 4, 2, 1
        },

        CrateBooks = {
            6, 4, 2, 1, 0.5
        },

        PostOfficeBooks = {
            6, 4, 2, 1, 0.5
        },

        LivingRoomShelf = {
            0.1, 0.05, 0.025
        },

        ClassroomShelves = {
            2, 1, 0.5
        },
    }

end