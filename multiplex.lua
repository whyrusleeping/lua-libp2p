--[[
multiplex implements the 'mplex' stream multiplexer commonly used by libp2p.
--]]
local ythr = require("ythr")
local varint = require("varint")
local conn = require("conn")

local M = {}

NewStream = 0
Message = 1
Close = 3
Reset = 5

function readHeader(con)
	local h, err = varint.readUvarint(con)
	if err then return nil, nil, err end
	local ch = h >> 3
	local rem = h & 7
	return ch, rem, nil
end

function readPacket(con)
	local len = assert(varint.readUvarint(con))
	return con:receive(len)
end

local Multiplex = {}
Multiplex.__index = Multiplex

function Multiplex:new(con, handler, init)
	local mp = {}
	setmetatable(mp, Multiplex)
	mp.con = con
	mp.init = init
	mp.handler = handler
	mp.outchan = ythr.makeChan()
	mp.streamID = 0
	mp.streams = {}

	ythr.go(function () 
		mp:handleIncoming()
		print("handleIncoming exited...")
	end)

	ythr.go(function()
		while 1 do
			local val = mp.outchan:recv()
			local n, err = con:send(val)
			if err then
				print("SEND ERROR: ", err)
				return
			end
		end
	end)

	return mp
end

function Multiplex:nextStreamID()
	local sid = self.streamID
	self.streamID = self.streamID + 1
	return sid
end

function Multiplex:handleIncoming()
	while 1 do
		local ch, tag, err = readHeader(self.con)
		if err then return err end

		local pkt, err = readPacket(self.con)
		if err then
			print("read packet error: ", err)
			return err
		end

		self:handlePacket(ch, tag, pkt)
	end
end

function Multiplex:handlePacket(ch, tag, pkt)
	local chid = (ch << 1) + (tag & 1)
	local msch = self.streams[chid]

	if tag == NewStream then
		print("new stream: ", ch)
		if msch ~= nil then
			print("ERROR: received new stream for stream that already exists")
		end

		local str = makeStream(ch, 0, self.outchan)
		self.streams[chid] = str

		ythr.go(function ()
			self.handler(str)
			print("---- handler for stream exited: ", str.id)
		end)
	elseif tag == Message or tag == Message+1 then
		if msch == nil then
			print("ERROR: no such channel: ", ch)
			return
		end

		--print("got packet for stream: ", ch)
		msch.incoming:send(pkt)
	elseif tag == Close or tag == Close+1 then
		if msch == nil then
			return
		end
		if not msch.remoteClose then
			msch.incoming:close()
		end
		msch.remoteClose = true
	elseif tag == Reset or tag == Reset+1 then
		if msch == nil then
			return
		end
		if not msch.remoteClose then
			msch.incoming:close()
		end
		msch.localClose = true
		msch.remoteClose = true
	else
		print("unrecognized frame tag", tag)
	end
end

function Multiplex:newStream()
	local sid = self:nextStreamID()
	local s = makeStream(sid, 1, self.outchan)
	self.streams[(sid << 1) + 1] = s

	local header = (sid << 3) | NewStream

	local n, err = s:sendMsg(header, string.format("%d", sid))
	if err then return nil, err end
	return s, nil
end

local Stream = {}
Stream.__index = Stream

function makeStream(id, init, outgoing)
	local s = {}
	setmetatable(s, Stream)
	s.id = id
	s.init = init
	s.incoming = ythr.makeChan()
	s.remoteClose = false
	s.localClose = false
	s.con = conn:newChanConn(s.incoming, outgoing)

	return s
end

function Stream:receive(num)
	return self.con:receive(num)
end

function Stream:send(data)
	if self.localClose then
		return 0, "write after close"
	end
	if data:len() > 1000000 then
		return 0, "data too large to send!"
	end

	local header = (self.id << 3) | (Message + self.init)
	return self:sendMsg(header, data)
end

function Stream:close()
	if self.localClose then
		return nil
	end
	local header = (self.id << 3) | (Close + self.init)
	return self:sendMsg(header, "")
end

function Stream:reset()
	if self.localClose and self.remoteClose then
		return nil
	end
	local header = (self.id << 3) | (Reset + self.init)
	return self:sendMsg(header, "")
end

function Stream:sendMsg(header, data)
	local headerbuf = varint.UvarintBuf(header)
	local dlenbuf = varint.UvarintBuf(data:len())
	return self.con:send(headerbuf .. dlenbuf .. data)
end

return Multiplex
