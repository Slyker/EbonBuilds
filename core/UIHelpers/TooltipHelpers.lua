-- EbonBuilds: core/UIHelpers/TooltipHelpers.lua
-- Tooltip wiring for frames.

-- Spell tooltip (locked-icon style) ---------------------------------------

function EbonBuilds.UIHelpers.WireLockedIconTooltip(frame)
    frame:SetScript("OnEnter", function(self)
        local id = self.spellId or self._spellId
        if not id then return end
        local spellName = GetSpellInfo(id)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if spellName then GameTooltip:AddLine(spellName, 1, 0.82, 0) end
        if utils and utils.GetSpellDescription then
            local desc = utils.GetSpellDescription(id, 500, 1)
            if desc and desc ~= "" then GameTooltip:AddLine(desc, 1, 1, 1, true) end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Generic tooltip wiring --------------------------------------------------

function EbonBuilds.UIHelpers.WireTooltip(frame, enterFn)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if enterFn(self) ~= false then
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
