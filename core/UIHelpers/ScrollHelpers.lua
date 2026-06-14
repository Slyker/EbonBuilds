-- EbonBuilds: core/UIHelpers/ScrollHelpers.lua
-- Scrollbar wiring and scroll frame combos.

-- Scrollbar wiring --------------------------------------------------------

function EbonBuilds.UIHelpers.WireScrollBar(scrollFrame, scrollBar, stepSize, onScroll)
    stepSize = stepSize or 20
    scrollBar:SetValueStep(stepSize)

    scrollBar:SetScript("OnValueChanged", function(self, value)
        if onScroll then onScroll(value) end
    end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local v = scrollBar:GetValue()
        local mn, mx = scrollBar:GetMinMaxValues()
        scrollBar:SetValue(math.max(mn, math.min(mx, v - delta * stepSize)))
    end)
end

-- ScrollFrame + child + bar combo ----------------------------------------

function EbonBuilds.UIHelpers.CreateScroller(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(1)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    local bar = CreateFrame("Slider", nil, scroll, "UIPanelScrollBarTemplate")
    bar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    -2, -4)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2,  4)
    bar:SetValueStep(20)

    return scroll, child, bar
end

-- Wire scroll bar to target (nil=SetVerticalScroll, frame=SetPoint, fn=callback)

function EbonBuilds.UIHelpers.WireScroller(scrollFrame, bar, stepSize, target)
    stepSize = stepSize or 20
    bar:SetValueStep(stepSize)

    local onScroll
    if type(target) == "function" then
        onScroll = target
    elseif target then
        onScroll = function(value) target:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, value) end
    else
        onScroll = function(value) scrollFrame:SetVerticalScroll(value) end
    end

    bar:SetScript("OnValueChanged", function(self, value) onScroll(value) end)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local v = bar:GetValue()
        local mn, mx = bar:GetMinMaxValues()
        bar:SetValue(math.max(mn, math.min(mx, v - delta * stepSize)))
    end)
end
