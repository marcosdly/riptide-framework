--!strict
-- Mock RemoteFunction for Lune testing
-- Simulates Roblox RemoteFunction

export type MockRemoteFunction = {
	OnServerInvoke: ((...any) -> any)?,
	OnClientInvoke: ((...any) -> any)?,
	InvokeServer: (self: MockRemoteFunction, ...any) -> any,
	InvokeClient: (self: MockRemoteFunction, player: any, ...any) -> any,
}

local MockRemoteFunction = {}
MockRemoteFunction.__index = MockRemoteFunction

function MockRemoteFunction.new(): MockRemoteFunction
	local self = setmetatable({
		OnServerInvoke = nil :: ((...any) -> any)?,
		OnClientInvoke = nil :: ((...any) -> any)?,
	}, MockRemoteFunction)
	return (self :: any) :: MockRemoteFunction
end

function MockRemoteFunction:InvokeServer(...: any): any
	if self.OnServerInvoke then
		return self.OnServerInvoke(...)
	end
	return nil
end

function MockRemoteFunction:InvokeClient(_player: any, ...: any): any
	if self.OnClientInvoke then
		return self.OnClientInvoke(...)
	end
	return nil
end

return MockRemoteFunction
