-- 这是一个键值数据库的类/得是类吗
-- 查询key hash --> key --> 获得value

require"string"
require"common"
require"filesystem"
require"lang"
local class = require 'middleclass'


---@class KVDB
local KVDB = class('KVDB')


function KVDB:initialize(root,db_name)
    self.db_path = root..'/'..db_name..'/'
    log.info("db_path",self.db_path)--"/sdcard0/db/epc/"
    -- 数据库地址、数据库表名
end

function KVDB:key_hash(key) 
    local hash = string.format("%04X",crypto.crc16("MODBUS",key))
    local splited = string.split_by_chunk(hash, 1)
    return self.db_path..table.concat({unpack(splited,1,4)}, '/')
end

function KVDB:key_map(key) 
    local path =  self:key_hash(key)
    filesystem.creat_folder(path)
    local key_path = path..'/'..key..'.json'
    
    log.info("key_path",path,key_path)--"/sdcard0/db/epc/0/F/1/4/.....json"
    return key_path
end

function KVDB:read(key)
    local folder_path = self:key_hash(key)
    local file_path = folder_path..'/'..key..'.json'

    if filesystem.path_exists(folder_path) and io.exists(file_path) then
        local json_content = io.readFile(file_path)
        log.info("read",json_content)
        return json.decode(json_content)
    else
        return nil
    end
end

function KVDB:write(key,table_content) 
    local path = self:key_map(key)
     return  io.writeFile(path, json.encode(table_content),"w")
end

function KVDB:delete(key) 
    local folder_path = self:key_hash(key)
    local file_path = folder_path..'/'..key..'.json'
     return  os.remove(file_path)
end

return KVDB

-- TODO:自动更新功能