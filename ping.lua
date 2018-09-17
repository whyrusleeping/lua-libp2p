local M = {}

function randomString()
	local buf = ""
	for i=1,32,1 do
		local v = math.random(256)
		buf = buf .. string.char(v-1)
	end
	return buf
end

function M.doPing(str)
	print("PING!")
	for i=1,10,1 do
		local pingVal = randomString()
		local t = os.clock()
		local n, err = str:send(pingVal)
		if err then
			print("ping error: ", err)
			return err
		end
		local back, err = str:receive(32)
		if err then
			print("ping recv error: ", err)
			return err
		end
		local took = os.clock() - t
		print("ping took: ", took)
	end
	str:close()
end

return M
