-- Shared by tint and geometry code after it has validated and read its inputs.
local _, private = ...

-- Round the public input to the nearest binary32 value, ties to even.
-- Neighboring values on opposite sides of a power of two have different spacing.
local function roundToFloat32(value)
    local magnitude = math.abs(value * 1.0)
    local step = 2^-149
    if magnitude >= 2^128 then return value < 0 and -math.huge or math.huge end
    if magnitude >= 2^-126 then
        local bin = 2 ^ math.floor(math.log(magnitude) / math.log(2))
        if bin > magnitude then bin = bin / 2 elseif bin * 2 <= magnitude then bin = bin * 2 end
        step = bin * 2^-23
    end
    local scaled = magnitude / step
    local units = math.floor(scaled)
    local fraction = scaled - units
    if fraction > .5 or (fraction == .5 and units % 2 == 1) then units = units + 1 end
    local stored = units * step
    if stored >= 2^128 then stored = math.huge end
    return value < 0 and -stored or stored
end

private.RoundToFloat32 = roundToFloat32
