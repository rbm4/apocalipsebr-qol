ProfessionItems_FlierDiary = ProfessionItems_FlierDiary or {}

ProfessionItems_FlierDiary.OnCreateDiaryPage = function(item)
    if not item then return end

    local fullType = item:getFullType()              -- ProfessionItems.DiaryPage1
    local page = string.match(fullType, "%.(.+)$")   -- DiaryPage1
    if not page then return end

    -- PrintMedia exclusivo (igual ao Flier Nolan)
    item:getModData().printMedia = {
        id    = page,
        title = "Print_Media_" .. page .. "_title",
        info  = "Print_Media_" .. page .. "_info",
        text  = "Print_Text_"  .. page .. "_info",
    }

    -- Nome customizado — APENAS NO CLIENT
    if not isServer() then
        local baseName   = getText(item:getDisplayName())
        local mediaTitle = getText("Print_Media_" .. page .. "_title")

        if baseName and mediaTitle then
            item:setCustomName(true)
            item:setName(baseName .. ": " .. mediaTitle)
        end
    end
end
