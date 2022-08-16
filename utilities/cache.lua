require"lang"
require"sys"
local class = require 'middleclass'

---@class Cache
local Cache = class('Cache')
local element = {
    key = "",-- string 或者 hash值
    value = "", -- 结构体
    countdown = 0 --自动销毁时间
}

function Cache:initialize() 
    -- 如果是C的话就创建
    self.catch_table = {}
    self.size = 10-- 这个也可能要改
    for i=1,self.size do
        self.catch_table[i] = lang.deepcopy(element)
    end
    self:clock()
end

function Cache:clock()
    sys.timerLoopStart(function ()
        for i=1,self.size do
            if self.catch_table[i].countdown > 0 then
                self.catch_table[i].countdown = self.catch_table[i].countdown - 1
            end
        end
    end, 1000)
end

function Cache:read(key) 
    for i=1,self.size do
        if self.catch_table[i].key == key and self.catch_table[i].countdown > 0 then
            return self.catch_table[i].value
        end
    end
    return nil
end

function Cache:write(key,value,countdown) 
    local count_temp = countdown
    local index = 1
    for i=1,self.size do
        if self.catch_table[i].key == key then
            index = i
            break
        end
        if count_temp > self.catch_table[i].countdown then
            count_temp = self.catch_table[i].countdown
            index = i
        end
    end
    log.info("epc write",index, key)
    self.catch_table[index].key = key
    self.catch_table[index].value = value
    self.catch_table[index].countdown = countdown
end

return Cache