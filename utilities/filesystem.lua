module(..., package.seeall)

require"sys"
require"os"
require"string"
require"common"

--- 本函数能递归创建文件夹
---@param path string
function creat_folder(path)
    -- 如果path内含//也可以正常运行，但会创建奇怪的文件夹
    if path == ""  then return end
    if path == nil then return end
    if io.opendir(path) == 1  then
        io.closedir()
    else
        local remian_path, _ = string.match(path, "(.*)/(.*)")
        creat_folder(remian_path)--创建上级文件夹
        rtos.make_dir(path)
        creat_folder(path)--创建此级文件夹
    end
end

---@param path string 不允许相对路径
function ensure_path(path)
    local to_create_folders = {}
    local curr_path = path

    while(not path_exists(curr_path)) do
        local remian_path, top_path = string.match(curr_path, "(.*)/(.*)")
        curr_path = remian_path
        table.insert(to_create_folders, top_path)
    end

    for i = #to_create_folders, 1 , -1 do
        curr_path = curr_path .. '/' .. to_create_folders[i]
        rtos.make_dir(curr_path)
    end
    io.closedir()
end

---@param path string 不允许相对路径
function path_exists(path)
    if io.opendir(path) == 1 then
        io.closedir()
        return true
    end
    return false
end