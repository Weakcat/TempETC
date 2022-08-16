module(..., package.seeall)

function string.starts(String, Start)
    return string.sub(String,1,string.len(Start))==Start
end

function compsum(table_raw)
    local temp = 0
    for _,v in pairs(table_raw) do
        temp = temp + v
    end
    return bit.band(bit.bnot(temp)+1,0xFF)
end

function string.split_by_chunk(text, chunkSize)
    local s = {}
    for i=1, #text, chunkSize do
        s[#s+1] = text:sub(i,i+chunkSize - 1)
    end
    return s
end

function enum(tbl)
    for i = 1, #tbl do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

function date_format(clk)
    return string.format(
        "%04d-%02d-%02d'T'%02d:%02d:%02d.%03dZ",
        clk.year, clk.month, clk.day, clk.hour, clk.min, clk.sec, 0
    )
end

function switch(sels, cond, ...)
    local found = sels[cond]
    if found ~= nil then
        return found(...)
    end
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- 按需更新表的合法数据
function tableUpdate(orig_data,update_data)
    if type(orig_data) ~= 'table' then return false end
    if type(update_data) ~= 'table' then return false end
    for update_key, update_value in next, update_data, nil do--遍历 update_data的话是直接修改orig_data
        if type(update_value) ==type(orig_data[update_key]) then
            if type(update_value) == 'table' then
                tableUpdate(orig_data[update_key],update_value)
            else
                orig_data[update_key] = update_value
            end
        end
    end
    return true
end

function not_impl()
    assert(false, 'not implemented')
end

-- 当前是否还在保质期内
function indue(dueDate)
    local table_temp = { year=2020, month=1, day=1 }
    tableUpdate(table_temp,dueDate)
    log.info("etc open",json.encode(table_temp))
    local time_now = misc.getClock()
    if  (table_temp.year > time_now.year) or 
        (table_temp.year == time_now.year and table_temp.month > time_now.month) or 
        (table_temp.year == time_now.year and table_temp.month == time_now.month and table_temp.day >= time_now.day)
    then
        return true
    else
        return false
    end
end