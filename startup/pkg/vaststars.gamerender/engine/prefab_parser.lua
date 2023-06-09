local fs = require "filesystem"
local serialize = import_package "ant.serialize"
local assetmgr = import_package "ant.asset"
local mathpkg = import_package "ant.math"
local mc = mathpkg.constant

local function read_file(filename)
    local f
    if string.sub(filename, 1, 1) == "/" then
        f = assert(io.open(assetmgr.compile(filename), "rb"))
    else
        f = assert(io.open(filename, "rb"))
    end
    local c = f:read "a"
    f:close()
    return c
end

local function parse(fullpath)
    local template = serialize.parse(fullpath, read_file(fullpath))
    local patch = fullpath .. ".patch"
    -- duplicated code - ant.ecs/main.lua -> create_template()
    if fs.exists(fs.path(patch)) then
        local count = #template
        for index, value in ipairs(serialize.parse(patch, read_file(patch))) do
            if value.mount then
                if value.mount ~= 1 then
                    value.mount = count + index - 1
                end
            else
                value.mount = 1
            end
            template[#template + 1] = value
        end
    end
    return template
end

local function replace_material(template, material_file)
    for _, v in ipairs(template) do
        for _, policy in ipairs(v.policy) do
            if policy == "ant.render|render" or policy == "ant.render|simplerender" or policy == "ant.render|skinrender" then
                v.data.material = material_file
            end
        end
    end
    return template
end

local meshbin ; do
    local meshbin_caches = {}
    function meshbin(fullpath)
        if not meshbin_caches[fullpath] then
            local res = {}
            for _, v in ipairs(parse(fullpath)) do
                if v.data and v.data.mesh then
                    res[#res+1] = v.data
                end
            end
            meshbin_caches[fullpath] = res
        end
        return meshbin_caches[fullpath]
    end
end

local function slots(fullpath)
    local res = {}
    local t = parse(fullpath)
    for _, v in ipairs(t) do
        if v.data and v.data.slot then
            v.data.scene.s = v.data.scene.s or mc.ONE
            v.data.scene.r = v.data.scene.r or mc.IDENTITY_QUAT
            v.data.scene.t = v.data.scene.t or mc.ZERO_PT
            res[v.data.name] = v.data
        end
    end
    return res
end

local function root(fullpath)
    local t = parse(fullpath)
    assert(#t >= 1)
    return t[1]
end

return {
    parse = parse,
    replace_material = replace_material,
    meshbin = meshbin,
    slots = slots,
    root = root,
}