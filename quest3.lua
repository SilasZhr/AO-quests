---@diagnostic disable: undefined-field
-- Initializing global variables to store the latest game state and game host process.
Game = Game
Play = Play or false
Paid = Paid or false
InAction = InAction or false

LatestGameState = LatestGameState or nil

Logs = Logs or {}

local colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

local directionMap = {
    "Up",
    "Down",
    "Left",
    "Right",
    "UpRight",
    "UpLeft",
    "DownRight",
    "DownLeft"
}

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @return: Boolean indicating if the points are within the specified range.
local function inRange(x1, y1, x2, y2)
    return math.abs(x1 - x2) <= 1 and math.abs(y1 - y2) <= 1
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" and not Paid then
            if Play == false then
                -- prevent auto joining
                print(colors.red .. "[Wait] Set `Play` to true to join the game." .. colors.reset)
            else
                print(colors.red .. "[Wait] Auto-paying confirmation fees." .. colors.reset)
                ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
                Paid = true

                -- reset state
                LatestGameState = nil
                InAction = false
            end
        elseif not InAction and msg.Event == "Started-Game" then
            print(colors.green .. "Game Start." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })

            Play = false
            Paid = false
            InAction = true
        end
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        print(colors.gray .. "Get GameState" .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    end
)

-- Handler to update state and decide action
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        print(colors.blue .. "[Action]: Choosing Action" .. colors.reset)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        if LatestGameState.GameMode == "Playing" then
            -- Decides the next action based on player proximity and energy.
            -- If any player is within range, it initiates an attack; otherwise, moves randomly.
            local player = LatestGameState.Players[ao.id]
            local targetInRange = 0

            for target, state in pairs(LatestGameState.Players) do
                if target ~= ao.id and inRange(player.x, player.y, state.x, state.y) then
                    targetInRange = targetInRange + 1
                end
            end

            -- 1 / 3 chance of always running away
            local runAway = math.random(3) == 1
            if player.energy > 5 and targetInRange and targetInRange < 3 and not runAway then
                print(colors.blue .. "[Action]: Attack" .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy) })
            else
                local randomIndex = math.random(#directionMap)
                print(colors.blue .. "[Action]: Move " .. directionMap[randomIndex] .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex] })
            end

            ao.send({ Target = ao.id, Action = "Tick" })
        end
    end
)
