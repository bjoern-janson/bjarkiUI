-- Verify the actual SoftDark.lua PLAYER_REGEN_ENABLED event hot path.
-- An unchanged, previously tinted scene must NOT rescan its artwork on
-- every combat exit. A write refused during combat remains recoverable.
local region={color={1,.8,.5,.7},saturation=.2,reads=0,writes=0}
function region:GetObjectType()self.reads=self.reads+1;return "Texture"end
function region:GetVertexColor()return (unpack or table.unpack)(self.color)end
function region:SetVertexColor(...)self.color={...};self.writes=self.writes+1 end
function region:GetDesaturation()return self.saturation end
function region:SetDesaturation(v)self.saturation=v end
function region:GetAtlas()return "UI-HUD-ActionBar-IconFrame-Bags"end
function region:GetTexture()return nil end
function region:GetName()return nil end
function region:GetDrawLayer()return "BORDER"end
PlayerFrameTexture=region
bjarkiUISettings={softDarkPresetRevision="soft-dark-fixed-v1",softDarkEnabled=true}
SlashCmdList={}
local combat=false
InCombatLockdown=function()return combat end
C_AddOns={IsAddOnLoaded=function()return false end}
C_Timer={After=function()return true end}
local eventFrame
CreateFrame=function()
    eventFrame={RegisterEvent=function()end,
        SetScript=function(self,_,callback)self.callback=callback end}
    return eventFrame
end
hooksecurefunc=function()end
EventRegistry={RegisterCallback=function()end}
DEFAULT_CHAT_FRAME={AddMessage=function()end}
assert(loadfile("SoftDark.lua"))("bjarkiUI",{RoundToFloat32=function(v)return v end})
local function fire(event)eventFrame.callback(eventFrame,event)end
fire("PLAYER_LOGIN")
assert(math.abs(region.color[1]-.6)<.0001,"theme applied at first login")
region.reads,region.writes=0,0
fire("PLAYER_REGEN_ENABLED")
assert(region.reads==0 and region.writes==0,
    "clean combat exit must not repaint already-settled Soft Dark chrome")
combat=true
fire("PLAYER_REGEN_ENABLED")
combat=false
fire("PLAYER_REGEN_ENABLED")
assert(region.reads>0,"deferred theme work must be recoverable")
print("bjarkiUI Soft Dark clean combat-exit fastpath: passed")
