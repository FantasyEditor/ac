local buf

local function sort_pairs(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys+1] = k
    end
    table.sort(keys)
    local i = 0
    return function ()
        i = i + 1
        local k = keys[i]
        return k, t[k]
    end
end

local function sort_keys_pairs(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys+1] = k
    end
    table.sort(keys, function (a, b)
        local t1 = type(t[a])
        local t2 = type(t[b])
        if t1 == 'table' and t2 ~= 'table' then
            return false
        elseif t1 ~= 'table' and t2 == 'table' then
            return true
        end
        return a < b
    end)
    local i = 0
    return function ()
        i = i + 1
        local k = keys[i]
        return k, t[k]
    end
end

local esc_map = {
	['\\'] = '\\\\',
	['\r'] = '\\r',
	['\n'] = '\\n',
	['\t'] = '\\t',
	['\'']  = '\\\'',
}

local function format_key(name, len)
    if type(name) == 'string' then
        name = name:gsub("[\\\r\n\t']", esc_map)
        if name:find('[^%w_]') then
            name = "'" .. name .. "'"
        end
    else
        name = tostring(name)
    end
    if len and #name < len then
        name = name .. (' '):rep(len - #name)
    end
    return name
end

local function format_value(value)
    if type(value) ~= 'string' then
        return value
    end
    value = value:gsub("[\\\r\n\t']", esc_map)
    return "'" .. value .. "'"
end

local convert_data

local function convert_array(data)
    buf[#buf+1] = '{' 
    for _, value in ipairs(data) do
        convert_data(value)
        buf[#buf+1] = ','
    end
    buf[#buf+1] = '}'
end

local function convert_hash(data)
    buf[#buf+1] = '{'
    for k, v in sort_pairs(data) do
        buf[#buf+1] = format_key(k)
        buf[#buf+1] = '='
        convert_data(v)
        buf[#buf+1] = ','
    end
    buf[#buf+1] = '}'
end

function convert_data(data)
    if type(data) == 'table' then
        if #data > 0 then
            convert_array(data)
        else
            convert_hash(data)
        end
    else
        buf[#buf+1] = format_value(data)
    end
end

local function max_key_len(obj)
    local max = 0
    for k in pairs(obj) do
        local key = format_key(k)
        if #key > max then
            max = #key
        end
    end
    return max
end

local function convert_obj(obj, level)
    local max = max_key_len(obj)
    for key, data in sort_keys_pairs(obj) do
        if type(data) == 'table' then
            if level == 0 then
                buf[#buf+1] = '[.' .. format_key(key) .. ']\r\n'
                convert_obj(data, 1)
            elseif #data > 0 then
                buf[#buf+1] = format_key(key, max) .. ' = '
                convert_array(data)
                buf[#buf+1] = '\r\n'
            else
                buf[#buf+1] = format_key(key, max) .. ' = '
                convert_hash(data)
                buf[#buf+1] = '\r\n'
            end
        else
            buf[#buf+1] = ('%s = %s\r\n'):format(format_key(key, max), format_value(data))
        end
    end
end

return function (lni)
    buf = {}

    for name, obj in sort_pairs(lni) do
        buf[#buf+1] = '[' .. format_key(name) .. ']\r\n'
        convert_obj(obj, 0)
    end
    
    return table.concat(buf)
end
