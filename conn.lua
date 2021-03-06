--[[
conn implements a buffered connection that uses either an underlying
socket, or a ythr channel to read and write from. It correctly yields
execution any time it would block.
TODO: doesn't yield on blocking writes
--]]
local ythr = require("ythr")

Conn = {}
Conn.__index = Conn

function Conn:new(con)
	local c = {}
	setmetatable(c, Conn)
	c.con = con
	c.buf = ""
	return c
end

function Conn:newChanConn(i, o)
	local c = {}
	setmetatable(c, Conn)
	c.ichan = i
	c.ochan = o
	c.buf = ""
	return c
end

function Conn:getData(num)
	if self.con ~= nil then
		return ythr.read(self.con, num)
	elseif self.ichan ~= nil then
		local buf = ""
		while buf:len() < num do
			local data, ok = self.ichan:recv()
			if not ok then
				return buf, nil
			end
			buf = buf .. data
		end
		return buf, nil
	else
		return nil, "programmer error: no conn or chan"
	end
end

function Conn:receive(num)
	if self.buf:len() >= num then
		local out = string.sub(self.buf, 1, num)
		self.buf = string.sub(self.buf, num+1)
		return out
	end

	local data, err = self:getData(num - self.buf:len())
	if err then return nil, err end

	local tmp = self.buf .. data
	local out = string.sub(tmp, 1, num)
	self.buf = string.sub(tmp, num+1)
	return out
end

function Conn:send(data)
	if self.con ~= nil then
		return self.con:send(data)
	else
		self.ochan:send(data)
		return data:len(), nil
	end
end

return Conn
