local type = type
local pairs = pairs
local gsub = string.gsub
local find = string.find
local tostring = tostring

local buf 

local esc_map = {
    ['\\'] = '\\\\',
    ['\r'] = '\\r',
    ['\n'] = '\\n',
    ['\t'] = '\\t',
    ['\''] = '\\\'',
}

local function format_key(name)
    if type(name) ~= 'string' then
        return tostring(name)
    end
    name = gsub(name, "[\\\r\n\t']", esc_map)
    return "'" .. name .. "'"
end

local function format_value(value)
    if type(value) ~= 'string' then
        return tostring(value)
    end
    value = gsub(value, "[\\\r\n\t']", esc_map)
    return "'" .. value .. "'"
end

local function convert_table(tbl)
    for key, data in pairs(tbl) do
        if type(data) == 'table' then
            buf[#buf+1] = format_key(key) .. '={'
            convert_table(data)
            buf[#buf+1] = '},'
        else
            buf[#buf+1] = format_key(key) .. '=' .. format_value(data) .. ','
        end
    end
end

local function convert_root(root)
    for key, data in pairs(root) do
        if type(data) == 'table' then
            buf[#buf+1] = format_key(key) .. '={'
            convert_table(data)
            buf[#buf+1] = '}'
        else
            buf[#buf+1] = format_key(key) .. '=' .. format_value(data)
        end
    end
end

return function (lni)
    buf = {'[root]'}

    convert_root(lni)

    return table.concat(buf, '\n')
end
