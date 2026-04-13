if SERVER then return end

local function PatchDButtonImageLayout()
    if _G.ZC_DButtonImageLayoutGuarded then return true end

    local ct = vgui and vgui.GetControlTable and vgui.GetControlTable("DButton")
    if not ct or not isfunction(ct.PerformLayoutImage) then return false end

    local original = ct.PerformLayoutImage

    ct.PerformLayoutImage = function(self, w, h)
        local img = self and self.m_Image
        if not IsValid(img) then return end
        local imgW, imgH
        if isfunction(img.GetImageSize) then
            imgW, imgH = img:GetImageSize()
        end
        imgW = tonumber(imgW) or img:GetWide() or 16
        imgH = tonumber(imgH) or img:GetTall() or 16

        if imgW <= 0 then imgW = 16 end
        if imgH <= 0 then imgH = 16 end

        local oldGetImageSize = img.GetImageSize
        img.GetImageSize = function() return imgW, imgH end

        local ok = pcall(original, self, w, h)

        img.GetImageSize = oldGetImageSize

        if ok then return end

        -- Safe fallback: center icon vertically and keep existing text-first behavior.
        local margin = self.m_iImageMargin or 4
        local bw, bh = self:GetSize()

        if self.m_bTextFirst then
            img:SetPos(bw - imgW - margin, math.floor((bh - imgH) * 0.5))
        else
            img:SetPos(margin, math.floor((bh - imgH) * 0.5))
        end

        img:SetSize(imgW, imgH)
    end

    _G.ZC_DButtonImageLayoutGuarded = true
    print("[DCityPatch] DButton image nil-size guard active.")
    return true
end

local function TryPatchDButtonImageLayout()
    if PatchDButtonImageLayout() then
        timer.Remove("ZC_DButtonImageNilGuardRetry")
    end
end

hook.Add("InitPostEntity", "ZC_DButtonImageNilGuardInit", TryPatchDButtonImageLayout)
timer.Simple(0, TryPatchDButtonImageLayout)
timer.Create("ZC_DButtonImageNilGuardRetry", 1, 10, TryPatchDButtonImageLayout)
