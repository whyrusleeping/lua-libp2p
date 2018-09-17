--[[
ythr is an implementation of a cooperatively scheduled concurrent
execution system. I'm implementing things to feel similar to go's
system of goroutines and channels. It handles socket waits, channel
sends and receives, and just general 'nice' thread yielding for 
expensive processes to not block execution.
--]]
local pq = require("pq")
local socket = require("socket")

local M = {}

local routines = {}
local readsockets = {}

local chansends = {}
local numsendwait = 0
local chanrecvs = {}
local numrecvwait = 0

function M.wakeSockets()
	local rsocks = {}
	for k, v in pairs(readsockets) do
		table.insert(rsocks, k)
	end
	if #rsocks == 0 then 
		return nil
	end
	local read, write, err = socket.select(rsocks, nil, nil)
	if err then 
		print("select error: ", err)
		return err
	end
	for i=1,#read,1 do
		local sock = read[i]
		if sock == nil then break end
		local rco = readsockets[sock]
		table.insert(routines, rco)
		readsockets[sock] = nil
	end
	return nil
end

function M.scheduler()
	while 1 do
		if #routines == 0 then
			local err = M.wakeSockets()
			if err then return err end
		end
		local co = table.remove(routines, 1)
		if co == nil then 
			print("out of tasks!", numrecvwait, numsendwait)
			if numrecvwait > 0 or numsendwait > 0 then
				print("Uh oh! Channel deadlock!")
				print("sends:")
				for k,v in pairs(chansends) do
					for a, b in pairs(v) do
						print(debug.traceback(b))
					end
				end
				print("recvs:")
				for k,v in pairs(chanrecvs) do
					for a, b in pairs(v) do
						print(debug.traceback(b))
					end
				end
			end
			return
		end
		local cont, nstate = coroutine.resume(co)
		if not cont then print("coroutine exited:", nstate) end
		if nstate ~= nil and cont then
			if nstate.waiton == "sock-read" then
				readsockets[nstate.socket] = co
			elseif nstate.waiton == "nowait" then
				table.insert(routines, co)
			elseif nstate.waiton == "chan-send" then
				local chtab = chanrecvs[nstate.chan]
				local sent = false
				if chtab ~= nil then
					local maybechan = table.remove(chtab, 1)
					if maybechan ~= nil then
						numrecvwait = numrecvwait - 1
						table.insert(routines, maybechan)
						table.insert(routines, co)
						sent = true
					end
				end

				if not sent then
					local ochtab = chansends[nstate.chan]
					if ochtab == nil then
						ochtab = {}
						chansends[nstate.chan] = ochtab
					end
					table.insert(ochtab, co)
					numsendwait = numsendwait + 1
				end
			elseif nstate.waiton == "chan-recv" then
				local chtab = chansends[nstate.chan]
				local sent = false
				if chtab ~= nil then
					local maybechan = table.remove(chtab, 1)
					if maybechan ~= nil then
						numsendwait = numsendwait - 1
						table.insert(routines, maybechan)
						table.insert(routines, co)
						sent = true
					end
				end

				if not sent then
					local ochtab = chanrecvs[nstate.chan]
					if ochtab == nil then
						ochtab = {}
						chanrecvs[nstate.chan] = ochtab
					end
					table.insert(ochtab, co)
					numrecvwait = numrecvwait + 1
				end
			elseif nstate.waiton == "chan-close" then
				local rchtab = chanrecvs[nstate.chan]
				local schtab = chansends[nstate.chan]

				table.insert(routines, co)
				if rchtab ~= nil then 
					while 1 do
						local co = table.remove(rchtab, 1)
						if co == nil then break end

						table.insert(routines, co)
					end
				end

				if schtab ~= nil then
					while 1 do
						local co = table.remove(schtab, 1)
						if co == nil then break end

						table.insert(routines, co)
					end
				end
			else
				print("unknown scheduler waiton value: ", nstate.waiton)
			end
		end
	end
end

function M.go(f)
	local co = coroutine.create(f)
	table.insert(routines, co)
end

function M.polite()
	coroutine.yield({
		waiton = "nowait",
	})
end

-- read reads at least the given number of bytes
function M.read(con, num)
	con:settimeout(0)
	local buf = ""
	while (buf:len() < num) do
		coroutine.yield({
			waiton = "sock-read",
			socket = con,
		})
		local v, err, part = con:receive("*a")
		if (not v) and(err ~= "timeout") then
			return nil, err
		end
		if part then
			return buf .. part, nil
		end
		print("ythr read buf len: ", v:len())

		if (not v) then return nil, "timeout" end

		buf = buf .. v
	end
	return buf
end

function M.accept(con)
	con:settimeout(0)
	while 1 do
		coroutine.yield({
			waiton = "sock-read",
			socket = con,
		})
		local c, err = con:accept()
		if (err ~= nil) and (err ~= "timeout") then
			return nil, err
		end

		if c then
			return c, nil
		end
	end

end

local Chan = {}
Chan.__index = Chan

function M.makeChan()
	local ch = {}
	setmetatable(ch, Chan)
	ch.hasVal = false
	return ch
end

function Chan:send(val)
	while 1 do
		if self.closed then
			print("ATTEMPTED TO SEND ON CLOSED CHANNEL")
			return 
		end
		if self.hasVal then
			coroutine.yield({
				waiton = "chan-send",
				chan = self,
			})
		else
			self.hasVal = true
			self.val = val
			coroutine.yield({
				waiton = "chan-send",
				chan = self,
			})
			return
		end
	end
end

function Chan:recv()
	while not self.hasVal do
		if self.closed then
			return nil, false
		end
		coroutine.yield({
			waiton = "chan-recv",
			chan = self,
		})
	end

	self.hasVal = false
	local out = self.val
	self.val = nil
	return out, true
end

function Chan:close()
	self.closed = true
	coroutine.yield({
		waiton = "chan-close",
		chan = self,
	})
end

return M
