-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.
Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

function addLog(msg, text) -- Function definition commented for performance, can be used for debugging
    Logs[msg] = Logs[msg] or {}
    table.insert(Logs[msg], text)
end

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function findNearestPlayer()
    local me = LatestGameState.Players[ao.id]

    local nearestPlayer = nil
    local nearestDistance = nil

    for target, state in pairs(LatestGameState.Players) do
        if target == ao.id then
            goto continue
        end

        local other = state;
        local xdiff = me.x - other.x
        local ydiff = me.y - other.y
        local distance = math.sqrt(xdiff * xdiff + ydiff * ydiff)

        if nearestPlayer == nil or nearestDistance > distance then
            nearestPlayer = other
            nearestDistance = distance
        end

        ::continue::
    end

    return nearestPlayer
end

local directionMap = {
  { x = 0,  y = 1,  name = "Up" },
  { x = 0,  y = -1, name = "Down" },
  { x = -1, y = 0,  name = "Left" },
  { x = 1,  y = 0,  name = "Right" },
  { x = 1,  y = 1,  name = "UpRight" },
  { x = -1, y = 1,  name = "UpLeft" },
  { x = 1,  y = -1, name = "DownRight" },
  { x = -1, y = -1, name = "DownLeft" }
}

local basic_strategy = {
  [21] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [20] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [19] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [18] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [17] = {"S", "S", "S", "S", "S", "S", "S", "S", "S", "S"},
  [16] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [15] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [14] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [13] = {"S", "S", "S", "S", "S", "H", "H", "H", "H", "H"},
  [12] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [11] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [10] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [9] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [8] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [7] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [6] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [5] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [4] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [3] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"},
  [2] = {"H", "H", "H", "H", "H", "H", "H", "H", "H", "H"}
}

-- get the best decision based on a table of basic strategy
local function getBestDecision(player_hand_value, dealer_upcard_value)
  if not basic_strategy[player_hand_value] then
    return "S"
  end

  local decision = basic_strategy[player_hand_value][dealer_upcard_value] or "S"
  return decision
end


function findApproachDirection()
    local me = LatestGameState.Players[ao.id]

    local approachDirection = { x = 0, y = 0 }
    local otherPlayer = findNearestPlayer()
    local approachVector = { x = otherPlayer.x - me.x, y = otherPlayer.y - me.y }
    approachDirection.x = approachDirection.x + approachVector.x
    approachDirection.y = approachDirection.y + approachVector.y
    approachDirection = normalizeDirection(approachDirection)

    local closestDirection = nil
    local closestDotResult = nil

    for direction, name in pairs(directionMap) do
        local normalized = normalizeDirection(direction)
        local dotResult = approachDirection.x * normalized.x + approachDirection.y + normalized.y

        if closestDirection == nil or closestDotResult < dotResult then
            closestDirection = name
            closestDotResult = dotResult
        end
    end

    return closestDirection
end

function isPlayerInAttackRange(player)
    local me = LatestGameState.Players[ao.id]

    if inRange(me.x, me.y, player.x, player.y, 1) then
        return true;
    end

    return false;
end

function normalizeDirection(direction)
    local length = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    return { x = direction.x / length, y = direction.y / length }
end

-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
function decideNextAction()
    local me = LatestGameState.Players[ao.id]

    local nearestPlayer = findNearestPlayer()
    local isNearestPlayerInAttackRange = isPlayerInAttackRange(nearestPlayer)

    nearestPlayer.isInAttackRange = isNearestPlayerInAttackRange;
    print(nearestPlayer)

    -- if points > 16 then -- this is a simple playing strategy
    -- this is a playing strategy from a table of basic strategy
    local decision = getBestDecision(points, dealerUpCard)
    
    if decision == "H" then
        if nearestPlayer.isInAttackRange then
            CurrentStrategy = "attack"
    else
        CurrentStrategy = "approach"
    end
    

    local tableOfActions = {}
    tableOfActions["approach"] = function()
        local direction = findApproachDirection()
        print(colors.blue .. "be angry. approach" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction })
    end
    tableOfActions["attack"] = function()
        print(colors.red .. "smash them. attack" .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(me.energy) })
    end

    tableOfActions[CurrentStrategy]()
    InAction = false -- InAction logic added
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
            InAction = true  -- InAction logic added
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif InAction then -- InAction logic added
            print("Previous action still in progress. Skipping.")
        end

        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            print(colors.gray .. "Getting game state..." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Print \'LatestGameState\' for detailed view.")
        print("energy:" .. LatestGameState.Players[ao.id].energy)
    end
)

-- Handler to decide the next best action.
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        if LatestGameState.GameMode ~= "Playing" then
            print("game not start")
            InAction = false -- InAction logic added
            return
        end
        print("Deciding next action.")
        decideNextAction()
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == undefined then
                print(colors.red .. "Unable to read energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
            elseif playerEnergy == 0 then
                print(colors.red .. "Player has insufficient energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
            else
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
            end
            InAction = false -- InAction logic added
            ao.send({ Target = ao.id, Action = "Tick" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)
