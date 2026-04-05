--!strict
local task = task
if not task then
	task = require("@lune/task") :: any
end

return {
	task = task,
}
