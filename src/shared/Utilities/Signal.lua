--!strict
-- Riptide/Utilities/Signal.lua
-- A fast, custom Signal implementation

local task = task
if not task then
	task = require("@lune/task")
end
export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
	_signal: Signal?,
	_fn: ((...any) -> ())?,
	_next: Connection?,
}

export type Signal = {
	_head: Connection?,
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Wait: (self: Signal) -> ...any,
	DisconnectAll: (self: Signal) -> (),
	Destroy: (self: Signal) -> (),
}

local Connection = {}
Connection.__index = Connection

function Connection.new(signal: Signal, fn: (...any) -> ()): Connection
	local self = setmetatable({
		Connected = true,
		_signal = signal,
		_fn = fn,
		_next = nil :: Connection?,
	}, Connection)
	return (self :: any) :: Connection
end

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false

	local signal = self._signal
	if signal then
		if signal._head == self then
			signal._head = self._next
		else
			local curr = signal._head
			while curr and curr._next ~= self do
				curr = curr._next
			end
			if curr then
				curr._next = self._next
			end
		end
	end

	-- Prevent memory leaks: clear references
	self._signal = nil
	self._fn = nil
	self._next = nil
end

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self = setmetatable({
		_head = nil,
	}, Signal)
	return (self :: any) :: Signal
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local connection = Connection.new(self, fn)
	if self._head then
		connection._next = self._head
	end
	self._head = connection
	return connection
end

function Signal:Once(fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	local curr = self._head
	while curr do
		local nextConn = curr._next
		if curr.Connected and curr._fn then
			-- Spawn prevents one yielding connection from blocking the rest
			task.spawn(curr._fn, ...)
		end
		curr = nextConn
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection: Connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

function Signal:DisconnectAll()
	local curr = self._head
	while curr do
		local nextConn = curr._next
		curr.Connected = false
		curr._signal = nil
		curr._fn = nil
		curr._next = nil
		curr = nextConn
	end
	(self :: any)._head = nil
end

function Signal:Destroy()
	self:DisconnectAll()
	setmetatable(self :: any, nil)
end

return Signal
