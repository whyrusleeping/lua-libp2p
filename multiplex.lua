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
	print("packet len", len)
	return con:receive(len)
end

local Multiplex = {}
Multiplex.__index = Multiplex

function Multiplex:new(con, handler)
	local mp = {}
	setmetatable(mp, Multiplex)
	mp.con = con
	mp.handler = handler
	mp.outchan = ythr.makeChan()
	mp.streams = {}

	print("conn in constructor: ", con, mp.con)
	ythr.go(function () 
		print("HI err: ", mp:handleIncoming())
	end)

	ythr.go(function()
		while 1 do
			print("awaiting the outchan")
			local val = mp.outchan:recv()
			print("sending some multiplex data!")
			local n, err = con:send(val)
			if err then
				print("SEND ERROR: ", err)
				return
			end
			print("multiplex data sent!")
		end
	end)

	return mp
end

function Multiplex:handleIncoming()
	while 1 do
		print("Read header")
		local ch, tag, err = readHeader(self.con)
		if err then return err end

		print("Read packet")
		local pkt, err = readPacket(self.con)
		if err then
			print("read packet error: ", err)
			return err
		end

		local msch = self.streams[ch]

		print("comparing: ", tag, NewStream)
		if tag == NewStream then
			if msch ~= nil then
				print("ERROR: received new stream for stream that already exists")
			end
			print("new stream!")
			local newch = ythr.makeChan()
			local str = makeStream(ch, 0, newch, self.outchan)
			self.streams[ch] = str

			ythr.go(function ()
				self.handler(str)
			end)
		elseif tag == Message or tag == Message+1 then
			if msch == nil then
				print("ERROR: no such channel: ", ch)
				return
			end

			msch.incoming:send(pkt)
		elseif tag == Close or tag == Close+1 then
			print("close!", ch)
		elseif tag == Reset or tag == Reset+1 then
			print("reset!", ch)
		else
			print("unrecognized frame tag", tag)
		end
	end
end

local Stream = {}
Stream.__index = Stream

function makeStream(id, init, incoming, outgoing)
	local s = {}
	setmetatable(s, Stream)
	s.id = id
	s.init = init
	s.incoming = incoming
	s.con = conn:newChanConn(incoming, outgoing)

	return s
end

function Stream:receive(num)
	return self.con:receive(num)
end

function Stream:send(data)
	print("STREAM SEND")
	if data:len() > 1000000 then
		return "data too large to send!"
	end

	local header = (self.id << 3) | (Message + self.init)
	return self:sendMsg(header, data)
end

function Stream:sendMsg(header, data)
	print("SEND MSG")
	local headerbuf = varint.UvarintBuf(header)
	local dlenbuf = varint.UvarintBuf(data:len())
	return self.con:send(headerbuf .. dlenbuf .. data)
end

return Multiplex
