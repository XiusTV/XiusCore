--[[
    Flat dark styling shared by the options window, minimap button, and movers.
]]

local Media = {}
XiusUI.Media = Media

Media.bg = { 11 / 255, 12 / 255, 15 / 255, 0.98 }
Media.border = { 42 / 255, 47 / 255, 61 / 255, 1 }
Media.sidebar = { 15 / 255, 17 / 255, 22 / 255, 1 }
Media.panel = { 20 / 255, 23 / 255, 31 / 255, 1 }
Media.raised = { 27 / 255, 31 / 255, 42 / 255, 1 }
Media.headerBar = { 22 / 255, 25 / 255, 34 / 255, 1 }
Media.menuBg = { 11 / 255, 12 / 255, 15 / 255, 0.98 }
Media.menuBorder = { 42 / 255, 47 / 255, 61 / 255, 1 }
Media.text = { 1, 1, 1, 1 }
Media.muted = { 184 / 255, 192 / 255, 208 / 255, 1 }
Media.accent = { 229 / 255, 169 / 255, 60 / 255, 1 }
Media.hover = { 245 / 255, 196 / 255, 99 / 255, 1 }
Media.white = "Interface\\Buttons\\WHITE8X8"
Media.font = "Fonts\\FRIZQT__.TTF"

Media.backdrop = {
    bgFile = Media.white,
    edgeFile = Media.white,
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function Media:Template()
    if BackdropTemplateMixin then
        return "BackdropTemplate"
    end
    return nil
end

function Media:ApplyAccent(r, g, b)
    self.accent[1] = r
    self.accent[2] = g
    self.accent[3] = b
    self.accent[4] = 1
end

local function FontApplied(fs)
    if not fs or not fs.GetFont then
        return false
    end
    local ok, face = pcall(fs.GetFont, fs)
    return ok and type(face) == "string" and face ~= ""
end

local function TryFace(fs, face, size, flags)
    if type(face) ~= "string" or face == "" then
        return false
    end
    local ok = pcall(fs.SetFont, fs, face, size, flags or "")
    if ok and FontApplied(fs) then
        return true
    end
    ok = pcall(fs.SetFont, fs, face, size, "OUTLINE")
    return ok and FontApplied(fs)
end

local fontFaces

local function FontFaces()
    if fontFaces then
        return fontFaces
    end
    fontFaces = {
        "Fonts\\FRIZQT__.TTF",
        Media.font,
    }
    if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
        fontFaces[#fontFaces + 1] = STANDARD_TEXT_FONT
    end
    local fontObject = GameFontHighlight or GameFontNormal or GameFontDisable
    if fontObject and fontObject.GetFont then
        local ok, face = pcall(fontObject.GetFont, fontObject)
        if ok and type(face) == "string" and face ~= "" then
            fontFaces[#fontFaces + 1] = face
        end
    end
    return fontFaces
end

function Media:Font(fs, size, color, flags)
    if not fs then
        return
    end
    local sizeN = size or 12
    local faces = FontFaces()
    local applied = false
    for i = 1, #faces do
        if TryFace(fs, faces[i], sizeN, flags) then
            applied = true
            break
        end
    end
    local fontObject = GameFontHighlight or GameFontNormal or GameFontDisable
    if not applied and fs.SetFontObject and fontObject then
        pcall(fs.SetFontObject, fs, fontObject)
        if fontObject.GetFont then
            local ok, face, _, objFlags = pcall(fontObject.GetFont, fontObject)
            if ok then
                TryFace(fs, face, sizeN, objFlags)
            end
        end
    end
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 1)
    pcall(fs.SetShadowOffset, fs, 1, -1)
    local tint = color or self.text
    pcall(fs.SetTextColor, fs, tint[1], tint[2], tint[3], tint[4] or 1)
end

local function EnsureEdges(frame)
    if frame._xiusEdges then
        return frame._xiusEdges
    end
    local edges = {}
    local names = { "top", "bottom", "left", "right" }
    for i = 1, 4 do
        local line = frame:CreateTexture(nil, "BORDER")
        line:SetTexture(Media.white)
        edges[names[i]] = line
    end
    edges.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges.top:SetHeight(1)
    edges.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges.bottom:SetHeight(1)
    edges.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges.left:SetWidth(1)
    edges.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges.right:SetWidth(1)
    frame._xiusEdges = edges
    return edges
end

function Media:Paint(frame, bg, border)
    if not frame then
        return
    end
    local fill = bg or self.bg
    local edge = border or self.border
    if frame.SetBackdrop then
        frame:SetBackdrop(self.backdrop)
        frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
        frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
        return
    end
    if not frame._xiusBg then
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetTexture(self.white)
        frame._xiusBg = tex
    end
    frame._xiusBg:SetVertexColor(fill[1], fill[2], fill[3], fill[4] or 1)
    local edges = EnsureEdges(frame)
    edges.top:SetVertexColor(edge[1], edge[2], edge[3], edge[4] or 1)
    edges.bottom:SetVertexColor(edge[1], edge[2], edge[3], edge[4] or 1)
    edges.left:SetVertexColor(edge[1], edge[2], edge[3], edge[4] or 1)
    edges.right:SetVertexColor(edge[1], edge[2], edge[3], edge[4] or 1)
end

function Media:Solid(parent, layer, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetTexture(self.white)
    tex:SetVertexColor(r, g, b, a or 1)
    return tex
end
