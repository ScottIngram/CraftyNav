-- History
-- keep track of navigation from one "page" to the next so you can go forwards and back.

-------------------------------------------------------------------------------
-- Module Loading
-------------------------------------------------------------------------------

local ADDON_NAME, ADDON_VARS = ...

---@class History
---@field ary table
---@field ptr number
local History = {}
ADDON_VARS.History = History

-------------------------------------------------------------------------------
-- Functions / Methods
-------------------------------------------------------------------------------

---@return History
function History:new()
    ---@type History
    local self = {
        ary = {},
        ptr = 0,
    }
    setmetatable(self, { __index = History })
    return self
end

function History:push(pageId)
    -- ignore dupe IDs
    if self.ary[self.ptr] == pageId then return end

    self.ptr = self.ptr + 1
    self:truncate()
    self.ary[self.ptr] = pageId
end

function History:truncate()
    local n = self.ptr
    local array = self.ary
    if n ~= #array then
        for i = #array, n, -1 do
            array[i] = nil
        end
    end
end

function History:rewind()
    if self.ptr > 1 then
        self.ptr = self.ptr - 1
    end

    return self.ary[self.ptr]
end

function History:forward()
    if self.ptr < #(self.ary) then
        self.ptr = self.ptr + 1
    end

    return self.ary[self.ptr]
end

function History:canRewind()
    return self.ptr and self.ptr > 1
end

function History:canForward()
    return self.ptr and self.ptr < #(self.ary)
end
