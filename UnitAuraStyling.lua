-- .274 recovery: the experimental target/focus replacement is retired.
-- Keep this filename to overwrite .272/.273 installations cleanly. This file
-- performs NO frame creation, event registration, timers, native aura writes,
-- cast-bar reanchoring, or protected-frame hooks. It only reports the disabled
-- route to BuffPresentation and handles the old slash command.
-- Existing customUnitAuraRows preferences are ignored, not rewritten.
-- A UI reload/restart is required; this cannot undo hooks in a running .273 UI.
bjarkiUIUnitAuraRows = {}

function bjarkiUIUnitAuraRows.GetStatus(_name)
    return "native (custom styling disabled)"
end

if type(SlashCmdList) == "table" then
    SLASH_BJARKIUIAURAS1 = "/buiauras"
    SlashCmdList.BJARKIUIAURAS = function()
        local text = "bjarkiUI .275: custom target/focus aura rows are disabled in this recovery build. Native rows are used; ToT/ToF cosmetic styling is retained."
        if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
            pcall(DEFAULT_CHAT_FRAME.AddMessage, DEFAULT_CHAT_FRAME, text)
        elseif type(print) == "function" then
            print(text)
        end
    end
end
