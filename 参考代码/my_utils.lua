module(...,package.seeall)

function xmodem_crc(ctx,data,crc_ini)
    if ctx > 0 then
        return crypto.crc16("USER-DEFINED",data,0x1021,crc_ini,0,0,0)
    else
        return 0
    end
end

function xmodem_num_table(data)
    local crc = 0x0000
    for key,value in ipairs(data)
    do
        crc = xmodem_crc(1,string.char(value),crc)
    end
    return {bit.band(bit.rshift(crc,8),0xFF),bit.band(crc,0xFF)}
end

