function packNetworkData(data)
    local function packData(t)
        local newTable = {}
        for k, v in pairs(t) do
            if type(v) == "number" then
                v = tostring(v)
            elseif type(v) == "table" then
                v = packData(v)
            end

            newTable[k] = v
        end
        return newTable
    end

    return packData(data)
end

function unpackNetworkData(data)
    local function unpackData(t)
        local newTable = {}
        for k, v in pairs(t) do
            if type(v) == "string" then
                v = tonumber(v) or v
            elseif type(v) == "table" then
                v = unpackData(v)
            end

            newTable[k] = v
        end
        return newTable
    end

    return unpackData(data)
end