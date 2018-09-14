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
			local data = self.ichan:recv()
			buf = buf .. data
		end
		return buf, nil
	else
		return nil, "programmer error: no conn or chan"
	end
end

function Conn:receive(num)
	print("in receive: ", num)
	if self.buf:len() >= num then
		print("buf should cover it: ", self.buf:len())
		local out = string.sub(self.buf, 1, num)
		self.buf = string.sub(self.buf, num+1)
		return out
	end

	print("receive data: ", num, self.buf:len())
	local data, err = self:getData(num - self.buf:len())
	if err then return nil, err end
	print("got data: ", data:len())

	local tmp = self.buf .. data
	local out = string.sub(tmp, 1, num)
	self.buf = string.sub(tmp, num+1)
	return out
end

function Conn:send(data)
	print("CON SEND")
	if self.con ~= nil then
		return self.con:send(data)
	else
		print("CONN: send data via chan")
		self.ochan:send(data)
		print("CONN: sent data via chan")
		return nil
	end
end

return Conn
