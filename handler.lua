---@module RemoteShell.handler

local RSW = require '.RemoteShell.window'
local bn = require '.bluenet'
local redrun  = require '.redrun'

local RSH = {}

local GNOME = {
    ["black"]     = 0x111111,
    ["blue"]      = 0x2A7BDE,
    ["brown"]     = 0xA2734C,
    ["cyan"]      = 0x2AA1B3,
    ["gray"]      = 0x444444,
    ["green"]     = 0x26A269,
    ["lightBlue"] = 0x00AEFF,
    ["lightGray"] = 0x777777,
    ["lime"]      = 0x33D17A,
    ["magenta"]   = 0xC061CB,
    ["orange"]    = 0xD06018,
    ["pink"]      = 0xF66151,
    ["purple"]    = 0xA347BA,
    ["red"]       = 0xC01C28,
    ["white"]     = 0xFFFFFF,
    ["yellow"]    = 0xF3F03E
}
--local colorI = log4l.new("/wolfos/logs", 7 --[[Time shift (here, +2 utc)]], nil)
for color, code in pairs(GNOME) do
    _G.term.setPaletteColor(colors[color], code)
    --colorI.info("#"..tostring(string.sub(string.format("%x", code),1,-1)).."  "..color)
end

local packetConversion = {
	query = "SQ",
	response = "SR",
	data = "SP",
	close = "SC",
	fileQuery = "FQ",
	fileSend = "FS",
	fileResponse = "FR",
	fileHeader = "FH",
	fileData = "FD",
	fileEnd = "FE",
	textWrite = "TW",
	textCursorPos = "TC",
	textGetCursorPos = "TG",
	textGetSize = "TD",
	textInfo = "TI",
	textClear = "TE",
	textClearLine = "TL",
	textScroll = "TS",
	textBlink = "TB",
	textColor = "TF",
	textBackground = "TK",
	textIsColor = "TA",
	textTable = "TT",
	event = "EV",
	SQ = "query",
	SR = "response",
	SP = "data",
	SC = "close",
	FQ = "fileQuery",
	FS = "fileSend",
	FR = "fileResponse",
	FH = "fileHeader",
	FD = "fileData",
	FE = "fileEnd",
	TW = "textWrite",
	TC = "textCursorPos",
	TG = "textGetCursorPos",
	TD = "textGetSize",
	TI = "textInfo",
	TE = "textClear",
	TL = "textClearLine",
	TS = "textScroll",
	TB = "textBlink",
	TF = "textColor",
	TK = "textBackground",
	TA = "textIsColor",
	TT = "textTable",
	EV = "event",
}

local packetTypes = {
    TC = 'setCursorPos',
    TW = 'write',
    TB = 'blit',
    TS = 'scroll',
    CT = 'clear',
    CL = 'clearLine',
    BG = 'setBackgroundColor',
    CB = 'setCursorBlink',
    FG = 'setTextColor',
}

--- @section RemoteShellHost 

---creates a Remote Handler
---@tparam string url
--@return RemoteHandler
function RSH.hostRemote(url)
    -- @type RemoteHandler
    local output = {}
    local con = bn.open(url)
    local w,h = term.getSize()
    local win = RSW(term.current(),1,1,w,h,true,output)
    term.redirect(win)
    function output.run()
        print("RSW")
        while true do
            local msg = con:receive()
            if type(msg) == "table" then
                if msg.event then
                    os.queueEvent(table.unpack(msg.data))
                end
            end
        end
    end
    local threadID = redrun.start(output.run)
    function output:packet(typ,...)
        return {
            type = typ,
            gtx = true,
            data = {...}
        }
    end
    function output:send(typ,...)
        local data = self:packet(typ,...)
        con:send(data)
    end

    --- Transmits setCursorPos
    ---@tparam number x
    ---@tparam number y
    function output:setCursorPos(x,y)
        self:send('setCursorPos',x,y)
    end

    --- Transmits write
    ---@tparam string text
    function output:write(text)
        self:send('write',text)
    end

    --- Transmits blit
    ---@tparam string text
    ---@tparam string fg
    ---@tparam string bg
    function output:blit(text,fg,bg)
        self:send('blit',text,fg,bg)
    end

    --- Transmits clear
    function output:clear()
        self:send('clear')
    end

    --- Transmits clearLine
    function output:clearLine()
        self:send('clearLine')
    end

    --- Transmits setCursorBlink
    ---@tparam boolean blink
    function output:setCursorBlink(blink)
        self:send('setCursorBlink',blink)
    end

    --- Transmits setBackgroundColor
    ---@tparam number color
    function output:setBackgroundColor(color)
        self:send('setBackgroundColor',color)
    end

    --- Transmits setTextColor
    ---@tparam number color
    function output:setTextColor(color)
        self:send('setTextColor',color)
    end

    --- Transmits scroll
    ---@tparam number n
    function output:scroll(n)
        self:send('scroll',n)
    end


    
    return output
end

--- @section RemoteShell
---@tparam string url
function RSH.createRemote(url)
    local output = {}
    local con = bn.open(url)
    local w,h = term.getSize()
    local bar = window.create(term.native(),1,1,w,1,true)
    local win = window.create(term.current(),1,2,w,h-1,true)
    
    function output.keys()
        while true do
            con:send({
                event=true,
                data={os.pullEvent()}
            })
        end
    end

    function output.renr()
        while true do
            local msg = con:receive()
            --print(msg)
            if type(msg) == "table" then
                
                if msg.gtx then
                    win[msg.type](table.unpack(msg.data))
                end
            end
        end
    end
    function DrawBar()
        bar.setBackgroundColor(colors.gray)
        bar.clear()
        bar.setCursorPos(1,1)
        bar.setTextColor(colors.blue)
        bar.write("TRoB")
        bar.setTextColor(colors.orange)
        bar.write(' | ')
        bar.setTextColor(colors.green)
        bar.write(url)
    end

    win.clear()
    DrawBar()
    parallel.waitForAll(
        output.keys,
        output.renr        
    )
end

return RSH