local M = {}

function M.readUvarint(r)
	x = 0
	s = 0
	for i=0,10,1 do
		local bs = assert(r:receive(1))
		local b = string.byte(bs, 1)
		if(b < 0x80) then
			if (i > 9 or (i == 9 and b > 1)) then
				return x, "overflow"
			end
			return x | (b << s), nil
		end
		x = x | ((b & 0x7f) << s)
		s = s + 7
	end
end

function M.UvarintBuf(x)
	local buf = ""
	local i = 0
	while x > 0x80 do
		buf = buf .. string.char((x & 0xff) | 0x80)
		x = x >> 7
		i = i + 1
	end
	buf = buf .. string.char(x & 0xff)
	return buf
end

return M
