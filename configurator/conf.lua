require"string"
require"common"
require"filesystem"
require"lang"
local class = require 'middleclass'

local CONF_DIR = '/conf/'

---@class Configurator
local Configurator = class('Configurator')

---@param name String 配置名
---@param version String 配置版本
---@param default table 默认配置
function Configurator:initialize(name, version, default) 
    local conf_folder = CONF_DIR..name
    self.name = name
    self.content = lang.deepcopy(default)
    self.default = lang.deepcopy(default) ---@private
    self.conf_path = conf_folder..'/'..version..'.json' ---@private
    self.back_path = conf_folder..'/'..version..'.back' ---@private
    self.md5_path = conf_folder..'/'..version..'.md5'  ---@private
    filesystem.creat_folder(conf_folder)
end

function Configurator:versionChange(version) --TODO:版本转换
    local conf_folder = CONF_DIR..self.name
    self.conf_path = conf_folder..'/'..version..'.json' ---@private
    self.back_path = conf_folder..'/'..version..'.back' ---@private
    self.md5_path = conf_folder..'/'..version..'.md5'  ---@private
    filesystem.creat_folder(conf_folder)
end


function Configurator:_Read()
    if io.exists(self.conf_path) and io.exists(self.back_path) and io.exists(self.md5_path) then
        -- lualibc_fopen fail -4200062
        local json_content = ""
        if crypto.md5(self.conf_path,"file") == io.readFile(self.md5_path) then
            json_content = io.readFile(self.conf_path)
        else
            json_content = io.readFile(self.back_path)
        end
        local table_content,result,errinfo = json.decode(json_content)--可以打log
        if result == true then
            return table_content
        else
            return nil
        end
    else
        return nil
    end

end 

---@param table_content table
function Configurator:_Write(table_content)
    local json_content= json.encode(table_content)

    io.writeFile(self.conf_path,json_content)
    io.writeFile(self.md5_path,crypto.md5(self.conf_path,"file"))
    io.writeFile(self.back_path,json_content)

end

function Configurator:Reset()
    self.content = lang.deepcopy(self.default)
    self:_Write(self.default)
end

function Configurator:Save()
    self:_Write(self.content)
end

function Configurator:Fetch()
    local table_content = self:_Read()
    if table_content ~= nil then 
        self.content = table_content
        log.info("Fetch","there is file")
    else
        log.info("Fetch","there is not file")
        self:Save()
    end
    return lang.deepcopy(self.content)
end

function Configurator:Update(table_update)
    lang.tableUpdate(self.content,table_update)
    self:Save()
end
return Configurator

-- TODO:自动更新功能